/*
 * uvctui - a small TUI for the UVC controls of the Apple Thunderbolt Display's
 * built-in FaceTime HD camera (05ac:1112).
 *
 * macOS exposes almost nothing through AVFoundation for this camera (auto or
 * locked exposure, and that is all), so this talks UVC over libusb directly.
 * Note that the camera implements no Gain control at all - the Processing Unit
 * advertises bmControls 0x00157f, with D9 clear - so there is no gain row here.
 *
 *   cc uvctui.c -o uvctui -I$(brew --prefix)/include -L$(brew --prefix)/lib -lusb-1.0 -lncurses
 */
#include <locale.h>
#include <ncurses.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libusb-1.0/libusb.h>

#define VID 0x05ac
#define PID 0x1112
#define IFACE 0

#define SET_CUR 0x01
#define GET_CUR 0x81
#define GET_MIN 0x82
#define GET_MAX 0x83
#define GET_RES 0x84
#define GET_DEF 0x87

#define OUT 0x21 /* host-to-device, class, interface */
#define IN  0xA1 /* device-to-host, class, interface */

typedef struct {
	const char *name;
	int selector, entity, len, is_signed;
	double scale;      /* display value = raw * scale */
	const char *unit;
	long cur, min, max, def, step;
	int ok;
} Ctl;

/* Camera Terminal is entity 1, Processing Unit is entity 3. */
static Ctl ctls[] = {
	{"exposure",   0x04, 1, 4, 0, 0.1, "ms", 0,0,0,0,0, 0},
	{"brightness", 0x02, 3, 2, 1, 1.0, "",   0,0,0,0,0, 0},
	{"gamma",      0x09, 3, 2, 0, 1.0, "",   0,0,0,0,0, 0},
	{"contrast",   0x03, 3, 2, 0, 1.0, "",   0,0,0,0,0, 0},
	{"saturation", 0x07, 3, 2, 0, 1.0, "",   0,0,0,0,0, 0},
	{"sharpness",  0x08, 3, 2, 0, 1.0, "",   0,0,0,0,0, 0},
	{"backlight",  0x01, 3, 2, 0, 1.0, "",   0,0,0,0,0, 0},
	{"wb temp",    0x0A, 3, 2, 0, 1.0, "K",  0,0,0,0,0, 0},
	{"wb auto",    0x0B, 3, 1, 0, 1.0, "",   0,0,0,0,0, 0},
};
static const int NCTL = sizeof ctls / sizeof *ctls;

static libusb_device_handle *dev;
static char status[128] = "";

static long uvc_get(int req, Ctl *c)
{
	unsigned char b[4] = {0};
	if (libusb_control_transfer(dev, IN, req, c->selector << 8,
	                            (c->entity << 8) | IFACE, b, c->len, 500) < 0)
		return LONG_MIN;
	long v = 0;
	for (int i = 0; i < c->len; i++)
		v |= ((long)b[i]) << (8 * i);
	if (c->is_signed && c->len == 2 && (v & 0x8000))
		v -= 0x10000;
	return v;
}

static int uvc_set(Ctl *c, long v)
{
	unsigned char b[4];
	for (int i = 0; i < c->len; i++)
		b[i] = (v >> (8 * i)) & 0xff;
	return libusb_control_transfer(dev, OUT, SET_CUR, c->selector << 8,
	                               (c->entity << 8) | IFACE, b, c->len, 500);
}

static void probe(Ctl *c)
{
	c->cur = uvc_get(GET_CUR, c);
	if (c->cur == LONG_MIN) { c->ok = 0; return; }
	c->ok  = 1;
	c->min = uvc_get(GET_MIN, c);
	c->max = uvc_get(GET_MAX, c);
	c->def = uvc_get(GET_DEF, c);
	/* Boolean controls such as wb auto answer GET_CUR but not GET_MIN/MAX. */
	if (c->min == LONG_MIN || c->max == LONG_MIN || c->max <= c->min) {
		c->min = 0;
		c->max = (c->len == 1) ? 1 : c->cur;
	}
	if (c->def == LONG_MIN)
		c->def = c->cur;
	long res = uvc_get(GET_RES, c);
	/* A resolution of 1 on a wide range makes for painfully slow arrow keys. */
	long span = c->max - c->min;
	c->step = (res > 0 && res > span / 200) ? res : (span / 100 > 0 ? span / 100 : 1);
}

static void refresh_all(void)
{
	for (int i = 0; i < NCTL; i++)
		if (ctls[i].ok)
			ctls[i].cur = uvc_get(GET_CUR, &ctls[i]);
}

static void apply(Ctl *c, long v)
{
	if (v < c->min) v = c->min;
	if (v > c->max) v = c->max;
	if (uvc_set(c, v) < 0)
		snprintf(status, sizeof status, "%s: device rejected the write%s",
		         c->name, c->selector == 0x0A ? " (turn wb auto off first)" : "");
	else
		status[0] = '\0';
	c->cur = uvc_get(GET_CUR, c); /* trust the camera, not our arithmetic */
}

#define BARW 28

static void bar(char *out, size_t n, long cur, long min, long max)
{
	long span = max - min;
	int fill = span > 0 ? (int)((double)(cur - min) / span * BARW + 0.5) : 0;
	if (fill < 0) fill = 0;
	if (fill > BARW) fill = BARW;
	out[0] = '\0';
	for (int x = 0; x < BARW; x++)
		strncat(out, x < fill ? "█" : "░", n - strlen(out) - 1);
}

static void draw(int sel)
{
	char b[BARW * 3 + 1];

	erase();
	attron(A_BOLD);
	mvprintw(0, 2, "FaceTime HD Camera (Display)");
	attroff(A_BOLD);
	mvprintw(0, 32, "05ac:1112");

	int row = 2;
	for (int i = 0; i < NCTL; i++) {
		Ctl *c = &ctls[i];
		if (!c->ok) continue;
		int on = (i == sel);

		if (on) attron(A_BOLD);
		mvprintw(row, 2, "%c %-11s", on ? '>' : ' ', c->name);
		bar(b, sizeof b, c->cur, c->min, c->max);
		printw(" %s %8.6g%-2s", b, c->cur * c->scale, c->unit);
		if (on) attroff(A_BOLD);
		row++;
	}

	Ctl *s = &ctls[sel];
	row++;
	mvprintw(row++, 2, "%s: %g … %g   default %g   step %g",
	         s->name, s->min * s->scale, s->max * s->scale,
	         s->def * s->scale, s->step * s->scale);
	mvprintw(row++, 2, "jk/↑↓ pick   hl/←→ adjust   HL coarse   0 default   R reset   q quit");
	if (status[0]) {
		attron(A_BOLD);
		mvprintw(row, 2, "%s", status);
		attroff(A_BOLD);
	}
	refresh();
}

int main(void)
{
	setlocale(LC_ALL, "");
	if (libusb_init(NULL) < 0) { fprintf(stderr, "libusb init failed\n"); return 1; }
	dev = libusb_open_device_with_vid_pid(NULL, VID, PID);
	if (!dev) {
		fprintf(stderr, "camera 05ac:1112 not found.\n"
		                "If the display was just woken, replug the Thunderbolt cable.\n");
		return 1;
	}
	for (int i = 0; i < NCTL; i++)
		probe(&ctls[i]);

	initscr();
	noecho();
	cbreak();
	curs_set(0);
	keypad(stdscr, TRUE);
	timeout(1000); /* also re-reads, so Apple's software AE shows up live */

	int sel = 0;
	while (ctls[sel].ok == 0 && sel < NCTL - 1) sel++;

	for (;;) {
		draw(sel);
		int ch = getch();
		Ctl *c = &ctls[sel];
		switch (ch) {
		case ERR:
			refresh_all();
			break;
		case 'q': case 'Q':
			goto out;
		case KEY_UP: case 'k':
			do { sel = (sel - 1 + NCTL) % NCTL; } while (!ctls[sel].ok);
			break;
		case KEY_DOWN: case 'j':
			do { sel = (sel + 1) % NCTL; } while (!ctls[sel].ok);
			break;
		case KEY_LEFT:  case 'h': apply(c, c->cur - c->step); break;
		case KEY_RIGHT: case 'l': apply(c, c->cur + c->step); break;
		case KEY_SLEFT:  case 'H': apply(c, c->cur - c->step * 10); break;
		case KEY_SRIGHT: case 'L': apply(c, c->cur + c->step * 10); break;
		case '0':
			apply(c, c->def);
			break;
		case 'R':
			for (int i = 0; i < NCTL; i++)
				if (ctls[i].ok) apply(&ctls[i], ctls[i].def);
			snprintf(status, sizeof status, "all controls reset to defaults");
			break;
		}
	}
out:
	endwin();
	libusb_close(dev);
	libusb_exit(NULL);
	return 0;
}
