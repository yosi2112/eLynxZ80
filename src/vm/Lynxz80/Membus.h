/*
	Homebrew dual Z80 CP/M machine Emulator "eLynxZ80"

	Author : yosi with OpenAI Codex
	Date   : 2026.05.02-

	[ memory bus ]
*/

#ifndef _LYNXZ80_MEMBUS_H_
#define _LYNXZ80_MEMBUS_H_

#include "../memory.h"

#define SIG_MEMBUS_ROMEN	0

class MEMBUS : public MEMORY
{
private:
	uint8_t rom[0x2000];
	uint8_t ram[0x10000];
	bool rom_enabled;

	void update_memory_map();
	void load_rom_image();

public:
	MEMBUS(VM_TEMPLATE* parent_vm, EMU* parent_emu) : MEMORY(parent_vm, parent_emu)
	{
		set_device_name(_T("Main Memory Bus"));
		memset(rom, 0xff, sizeof(rom));
		memset(ram, 0x00, sizeof(ram));
		rom_enabled = true;
	}
	~MEMBUS() {}

	void initialize();
	void reset();
	void write_signal(int id, uint32_t data, uint32_t mask);
	bool process_state(FILEIO* state_fio, bool loading);
};

#endif
