/*
	Lynx Z80 Emulator

	Author : OpenAI Codex
	Date   : 2026.05.08-

	[ display ]
*/

#include "display.h"
#include "../../fileio.h"
#include "LynxZ80.h"
#include "../upd7220.h"

#define STATE_VERSION 3

namespace {

static bool load_local_binary(const _TCHAR* path, uint8_t* buffer, size_t size)
{
	FILEIO fio;
	if(!fio.Fopen(create_local_path(path), FILEIO_READ_BINARY)) {
		return false;
	}
	fio.Fread(buffer, (int)size, 1);
	fio.Fclose();
	return true;
}

static void clear_screen(EMU* emu, scrntype_t color_off)
{
	for(int y = 0; y < SCREEN_HEIGHT; y++) {
		scrntype_t* dest = emu->get_screen_buffer(y);
		if(dest == NULL) {
			continue;
		}
		for(int x = 0; x < SCREEN_WIDTH; x++) {
			dest[x] = color_off;
		}
	}
}

static scrntype_t text_color(uint8_t attr)
{
	static const scrntype_t palette[8] = {
		RGB_COLOR(0, 0, 0),
		RGB_COLOR(255, 0, 0),
		RGB_COLOR(0, 255, 0),
		RGB_COLOR(255, 255, 0),
		RGB_COLOR(0, 0, 255),
		RGB_COLOR(255, 0, 255),
		RGB_COLOR(0, 255, 255),
		RGB_COLOR(255, 255, 255),
	};
	return palette[attr & 0x07];
}

static bool has_gvram_pixels(const uint8_t* gvram, uint32_t plane_size)
{
	for(int plane = 0; plane < 3; plane++) {
		const uint8_t* src = gvram + plane_size * plane;
		for(uint32_t i = 0; i < plane_size; i++) {
			if(src[i] != 0) {
				return true;
			}
		}
	}
	return false;
}

static uint8_t gvram_plane_byte(const uint8_t* gvram, uint32_t plane_size, int plane, uint32_t offset)
{
	return gvram[plane_size * plane + (offset % plane_size)];
}

}

void DISPLAY::initialize()
{
	font_loaded = load_local_binary(_T("FONT.ROM"), font, sizeof(font));
}

void DISPLAY::reset()
{
	memset(tvram, 0x00, sizeof(tvram));
	memset(gvram, 0x00, sizeof(gvram));
}

void DISPLAY::draw_gfx_screen(scrntype_t color_off)
{
	if(d_ggdc == NULL || sync_gfx == NULL || ra_gfx == NULL) {
		return;
	}
	if(!d_ggdc->get_start() && !has_gvram_pixels(gvram, GVRAM_PLANE_SIZE)) {
		return;
	}
/*
#ifdef _DEBUG
	static int gvram_draw_count = 0;
	if((gvram_draw_count & 0xff) == 0) {
		// Log first 256 bytes of GVRAM for debugging
		FILE* fp = fopen("gvram_dump.log", "a");
		if(fp != NULL) {
			fprintf(fp, "draw_gfx_screen call %d:\n", gvram_draw_count);
			for(int i = 0; i < 256 && i < (int)sizeof(gvram); i++) {
				if(i % 16 == 0) fprintf(fp, "\n%04X: ", i);
				fprintf(fp, "%02X ", gvram[i]);
			}
			fprintf(fp, "\n\n");
			fclose(fp);
		}
	}
	gvram_draw_count++;
#endif
	*/
	uint8_t cg = sync_gfx[0] & 0x22;
	int total = 0;
	int display_lines = (sync_gfx[6] | (sync_gfx[7] << 8)) & 0x3ff;
	bool duplicate_line = (cs_gfx != NULL && (cs_gfx[0] & 0x1f) == 1);
	bool drew_gfx_region = false;

	for(int i = 0; i < 4 && total < display_lines && total < SCREEN_HEIGHT; i++) {
		uint32_t tmp = 0;
		int ptr;
		int line;
		bool gfx;
		bool wide;

		tmp |= (uint32_t)ra_gfx[4 * i + 0];
		tmp |= (uint32_t)ra_gfx[4 * i + 1] << 8;
		tmp |= (uint32_t)ra_gfx[4 * i + 2] << 16;
		tmp |= (uint32_t)ra_gfx[4 * i + 3] << 24;
		ptr = (int)(tmp & 0x3ffff);
		line = (tmp >> 20) & 0x3ff;
		gfx = (cg == 2) ? true : (cg == 0x20) ? false : ((tmp & 0x40000000) != 0);
		wide = ((tmp & 0x80000000) != 0);
		if(!gfx) {
			total += duplicate_line ? line * 2 : line;
			continue;
		}
		drew_gfx_region = true;
		int effective_lines = duplicate_line ? line * 2 : line;
		for(int y = total; y < total + effective_lines && y < SCREEN_HEIGHT;) {
			scrntype_t* dest = emu->get_screen_buffer(y);
			int xstep = wide ? 16 : 8;
			for(int x = 0; x < SCREEN_WIDTH; x += xstep) {
				uint32_t offset = (uint32_t)(ptr++ & 0xffff);
				uint8_t pat_r = gvram_plane_byte(gvram, GVRAM_PLANE_SIZE, 0, offset);
				uint8_t pat_g = gvram_plane_byte(gvram, GVRAM_PLANE_SIZE, 1, offset);
				uint8_t pat_b = gvram_plane_byte(gvram, GVRAM_PLANE_SIZE, 2, offset);
				int repeat = wide ? 2 : 1;
				for(int b = 0; b < 8 && (x + b * repeat) < SCREEN_WIDTH; b++) {
					uint8_t mask = 0x80 >> b;
					bool r = ((pat_r & mask) != 0);
					bool g = ((pat_g & mask) != 0);
					bool bl = ((pat_b & mask) != 0);
					if(r || g || bl) {
						scrntype_t color = RGB_COLOR(r ? 255 : 0, g ? 255 : 0, bl ? 255 : 0);
						dest[x + b * repeat] = color;
						if(repeat == 2 && (x + b * repeat + 1) < SCREEN_WIDTH) {
							dest[x + b * repeat + 1] = color;
						}
					} else {
						dest[x + b * repeat] = color_off;
						if(repeat == 2 && (x + b * repeat + 1) < SCREEN_WIDTH) {
							dest[x + b * repeat + 1] = color_off;
						}
					}
				}
			}
			if(duplicate_line && (y + 1) < SCREEN_HEIGHT && (y + 1) < total + effective_lines) {
				scrntype_t* dest_next = emu->get_screen_buffer(y + 1);
				memcpy(dest_next, dest, SCREEN_WIDTH * sizeof(scrntype_t));
				y += 2;
			} else {
				y++;
			}
		}
		total += effective_lines;
	}
	if(!drew_gfx_region || total == 0 || total < SCREEN_HEIGHT) {
		uint32_t tmp = 0;
		tmp |= (uint32_t)ra_gfx[0];
		tmp |= (uint32_t)ra_gfx[1] << 8;
		tmp |= (uint32_t)ra_gfx[2] << 16;
		tmp |= (uint32_t)ra_gfx[3] << 24;
		int ptr = (int)(tmp & 0x3ffff);
		for(int y = 0; y < SCREEN_HEIGHT;) {
			scrntype_t* dest = emu->get_screen_buffer(y);
			for(int x = 0; x < SCREEN_WIDTH; x += 8) {
				uint32_t offset = (uint32_t)(ptr++ & 0xffff);
				uint8_t pat_r = gvram_plane_byte(gvram, GVRAM_PLANE_SIZE, 0, offset);
				uint8_t pat_g = gvram_plane_byte(gvram, GVRAM_PLANE_SIZE, 1, offset);
				uint8_t pat_b = gvram_plane_byte(gvram, GVRAM_PLANE_SIZE, 2, offset);
				for(int b = 0; b < 8 && (x + b) < SCREEN_WIDTH; b++) {
					uint8_t mask = 0x80 >> b;
					bool r = ((pat_r & mask) != 0);
					bool g = ((pat_g & mask) != 0);
					bool bl = ((pat_b & mask) != 0);
					dest[x + b] = (r || g || bl) ? RGB_COLOR(r ? 255 : 0, g ? 255 : 0, bl ? 255 : 0) : color_off;
				}
			}
			if(duplicate_line && (y + 1) < SCREEN_HEIGHT) {
				scrntype_t* dest_next = emu->get_screen_buffer(y + 1);
				memcpy(dest_next, dest, SCREEN_WIDTH * sizeof(scrntype_t));
				y += 2;
			} else {
				y++;
			}
		}
	}
}

void DISPLAY::draw_chr_screen(scrntype_t color_on, scrntype_t color_off)
{
	if(d_cgdc == NULL || sync_chr == NULL || ra_chr == NULL || cs_chr == NULL || !d_cgdc->get_start()) {
		return;
	}
	int total = 0;
	int al = (sync_chr[6] | (sync_chr[7] << 8)) & 0x3ff;
	uint32_t cursor_addr = d_cgdc->cursor_addr(0xfff);
	int cursor_top = d_cgdc->cursor_top();
	int cursor_bottom = d_cgdc->cursor_bottom();

	for(int i = 0; i < 4 && total < al && total < SCREEN_HEIGHT; i++) {
		uint32_t tmp = 0;
		int ptr;
		int line;
		bool wide;

		tmp |= (uint32_t)ra_chr[4 * i + 0];
		tmp |= (uint32_t)ra_chr[4 * i + 1] << 8;
		tmp |= (uint32_t)ra_chr[4 * i + 2] << 16;
		tmp |= (uint32_t)ra_chr[4 * i + 3] << 24;
		ptr = ((int)(tmp & 0x1fff) << 1) & 0xfff;
		line = (tmp >> 20) & 0x3ff;
		wide = ((tmp & 0x80000000) != 0);

		for(int y = total; y < total + line && y < SCREEN_HEIGHT;) {
			for(int x = 0; x < SCREEN_WIDTH; x += wide ? 16 : 8) {
				bool cursor = ((uint32_t)ptr == cursor_addr);
				uint8_t code = tvram[ptr++ & 0xfff];
				uint8_t attr = tvram[ptr++ & 0xfff];
				uint32_t font_base = (attr & 0x10) ? 0x1000 : 0x0000;
				uint8_t* pattern = &font[font_base + ((code & 0xff) << 4)];
				int repeat = wide ? 2 : 1;
				scrntype_t fg_color = text_color(attr);

				for(int l = y % 16; l < 16 && (y + l) < total + line && (y + l) < SCREEN_HEIGHT; l++) {
					uint8_t pat = font_loaded ? pattern[l] : 0;
					scrntype_t* dest = emu->get_screen_buffer(y + l);
					if((attr & 0x40) || ((attr & 0x80) && ((get_current_clock() & 0x20000) != 0))) {
						pat = 0;
					}
					if(attr & 0x08) {
						pat = ~pat;
					}
					bool cursor_line = cursor && l >= cursor_top && l <= cursor_bottom;
					if(cursor_line) {
						pat = ~pat;
					}
					for(int b = 0; b < 8 && (x + b * repeat) < SCREEN_WIDTH; b++) {
						bool dot = ((pat & (0x80 >> b)) != 0);
						if(dot) {
							dest[x + b * repeat] = fg_color;
							if(repeat == 2 && (x + b * repeat + 1) < SCREEN_WIDTH) {
								dest[x + b * repeat + 1] = fg_color;
							}
						}
					}
				}
			}
			y += 16 - (y % 16);
		}
		total += line;
	}
}

void DISPLAY::draw_screen()
{
	scrntype_t color_off = RGB_COLOR(0, 0, 0);
	scrntype_t color_on = RGB_COLOR(255, 255, 255);

	clear_screen(emu, color_off);
	draw_gfx_screen(color_off);
	draw_chr_screen(color_on, color_off);
	emu->set_vm_screen_lines(SCREEN_HEIGHT);
}

bool DISPLAY::process_state(FILEIO* state_fio, bool loading)
{
	if(!state_fio->StateCheckUint32(STATE_VERSION)) {
		return false;
	}
	if(!state_fio->StateCheckInt32(this_device_id)) {
		return false;
	}
	state_fio->StateArray(tvram, sizeof(tvram), 1);
	state_fio->StateArray(gvram, sizeof(gvram), 1);
	state_fio->StateArray(font, sizeof(font), 1);
	state_fio->StateValue(font_loaded);
	return true;
}
