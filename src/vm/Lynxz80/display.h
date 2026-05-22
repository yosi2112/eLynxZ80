/*
	Lynx Z80 Emulator

	Author : OpenAI Codex
	Date   : 2026.05.08-

	[ display ]
*/

#ifndef _LYNXZ80_DISPLAY_H_
#define _LYNXZ80_DISPLAY_H_

#include "../vm.h"
#include "../../emu.h"
#include "../device.h"

class UPD7220;

class DISPLAY : public DEVICE
{
private:
	static const uint32_t TVRAM_SIZE = 0x1000;
	static const uint32_t GVRAM_PLANE_SIZE = 0x10000;
	static const uint32_t GVRAM_SIZE = GVRAM_PLANE_SIZE * 3;

	UPD7220* d_cgdc;
	UPD7220* d_ggdc;
	uint8_t* sync_chr;
	uint8_t* ra_chr;
	uint8_t* cs_chr;
	uint8_t* sync_gfx;
	uint8_t* ra_gfx;
	uint8_t* cs_gfx;

	uint8_t tvram[TVRAM_SIZE];
	uint8_t gvram[GVRAM_SIZE];
	uint8_t font[0x2000];
	bool font_loaded;

	void draw_chr_screen(scrntype_t color_on, scrntype_t color_off);
	void draw_gfx_screen(scrntype_t color_off);

public:
	DISPLAY(VM_TEMPLATE* parent_vm, EMU* parent_emu) : DEVICE(parent_vm, parent_emu)
	{
		d_cgdc = NULL;
		d_ggdc = NULL;
		sync_chr = NULL;
		ra_chr = NULL;
		cs_chr = NULL;
		sync_gfx = NULL;
		ra_gfx = NULL;
		cs_gfx = NULL;
		memset(tvram, 0x00, sizeof(tvram));
		memset(gvram, 0x00, sizeof(gvram));
		memset(font, 0x00, sizeof(font));
		font_loaded = false;
		set_device_name(_T("Display"));
	}
	~DISPLAY() {}

	void initialize();
	void reset();
	void draw_screen();
	bool process_state(FILEIO* state_fio, bool loading);

	void set_context_gdc_chr(UPD7220* device, uint8_t* sync, uint8_t* ra, uint8_t* cs)
	{
		d_cgdc = device;
		sync_chr = sync;
		ra_chr = ra;
		cs_chr = cs;
	}
	void set_context_gdc_gfx(UPD7220* device, uint8_t* sync, uint8_t* ra, uint8_t* cs)
	{
		d_ggdc = device;
		sync_gfx = sync;
		ra_gfx = ra;
		cs_gfx = cs;
	}
	uint8_t* get_tvram()
	{
		return tvram;
	}
	uint8_t* get_gvram()
	{
		return gvram;
	}
	uint32_t get_gvram_size() const
	{
		return GVRAM_SIZE;
	}
};

#endif
