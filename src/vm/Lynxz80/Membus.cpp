/*
	Lynx Z80 Emulator

	Author : OpenAI Codex
	Date   : 2026.05.02-

	[ memory bus ]
*/

#include "Membus.h"

#define STATE_VERSION 1

void MEMBUS::load_rom_image()
{
	static const _TCHAR* const candidates[] = {
		_T("IPL.ROM"),
		_T("MAIN.ROM"),
		_T("BOOT.ROM"),
		_T("BASIC.ROM")
	};

	// A HALT-filled ROM keeps the machine stable when no dump is present yet.
	memset(rom, 0x76, sizeof(rom));
	rom[0] = 0xc3;
	rom[1] = 0x00;
	rom[2] = 0x00;

	for(size_t i = 0; i < sizeof(candidates) / sizeof(candidates[0]); i++) {
		if(read_bios(candidates[i], rom, sizeof(rom)) > 0) {
			return;
		}
	}
}

void MEMBUS::update_memory_map()
{
	set_memory_rw(0x0000, 0xffff, ram);
	if(rom_enabled) {
		set_memory_r(0x0000, 0x1fff, rom);
	}
}

void MEMBUS::initialize()
{
	MEMORY::initialize();
	load_rom_image();
	update_memory_map();
}

void MEMBUS::reset()
{
	rom_enabled = true;
	update_memory_map();
}

void MEMBUS::write_signal(int id, uint32_t data, uint32_t mask)
{
	if(id == SIG_MEMBUS_ROMEN) {
		bool next = ((data & mask) != 0);
		if(rom_enabled != next) {
			rom_enabled = next;
			update_memory_map();
		}
	}
}

bool MEMBUS::process_state(FILEIO* state_fio, bool loading)
{
	if(!state_fio->StateCheckUint32(STATE_VERSION)) {
		return false;
	}
	if(!state_fio->StateCheckInt32(this_device_id)) {
		return false;
	}
	state_fio->StateArray(rom, sizeof(rom), 1);
	state_fio->StateArray(ram, sizeof(ram), 1);
	state_fio->StateValue(rom_enabled);
	if(loading) {
		update_memory_map();
	}
	return true;
}
