/*
	Homebrew dual Z80 CP/M machine Emulator "eLynxZ80"

	Author : yosi with OpenAI Codex
	Date   : 2026.05.01-

	[ virtual machine ]
*/

#ifndef _LYNXZ80_H_
#define _LYNXZ80_H_

#define DEVICE_NAME		"Homebrew dual Z80 CP/M machine Lynx"
#define CONFIG_NAME		"lynxz80"

// device informations for virtual machine
#define FRAMES_PER_SEC		56.42
#define LINES_PER_FRAME		440
#define CPU_CLOCKS		4000000
#define SCREEN_WIDTH		640
#define SCREEN_HEIGHT		400
#define WINDOW_HEIGHT_ASPECT	480
#define UPD7220_HORIZ_FREQ	24830
#define UPD7220_MSB_FIRST
#define IO_ADDR_MAX		0x100
#define MAX_DRIVE		2

// device informations for win32
#define USE_DEBUGGER
#define USE_FLOPPY_DISK		2
#define USE_SOCKET
#define USE_SERIAL_TYPE		6
#define SERIAL_TYPE_DEFAULT	0
#define USE_SCREEN_FILTER
#define USE_STATE

#include "../../common.h"
#include "../../fileio.h"
#include "../vm_template.h"

class EMU;
class DEVICE;
class EVENT;
class MEMORY;
class MEMBUS;
class Z80;
class Z80DMA;
class Z80PIO;
class Z80SIO;
class Z80CTC;
class UPD7220;
class MB8877;
#ifdef USE_DEBUGGER
class DEBUGGER;
#endif
class FLOPPY;
class DISPLAY;
class KEYBOARD;
class SERIAL;
class MAINIO;
class SUBIO;

class MainSubBridge
{
public:
	static constexpr uint8_t kPortMinSub = 0x80;
	static constexpr uint8_t kStatusDrFull = 0x02;
	static constexpr uint8_t kStatusSubBusy = 0x01;

	MainSubBridge();

	void reset();

	uint8_t main_io_read(uint8_t addr) const;
	void main_io_write(uint8_t addr, uint8_t data);

	uint8_t sub_io_read(uint8_t addr);
	void sub_io_write(uint8_t addr, uint8_t data);

	bool dr_full() const;
	bool sub_busy() const;
	uint8_t main_to_sub_data() const;
	void set_state(uint8_t data, bool dr_full, bool sub_busy);

private:
	bool is_minsub_addr(uint8_t addr) const;
	uint8_t build_status() const;

	uint8_t main_to_sub_data_;
	bool dr_full_;
	bool sub_busy_;
};

class VM : public VM_TEMPLATE
{
protected:
	EVENT* event;
	MEMBUS* memory;
	MEMORY* memory_sub;
	Z80* cpu_main;
	Z80* cpu_sub;
#ifdef USE_DEBUGGER
	DEBUGGER* debugger_main;
	DEBUGGER* debugger_sub;
#endif
	Z80DMA* dma;
	Z80PIO* pio;
	Z80SIO* sio;
	Z80CTC* ctc;
	UPD7220* cgdc;
	UPD7220* ggdc;
	MB8877* fdc;
	FLOPPY* floppy;
	DISPLAY* display;
	KEYBOARD* keyboard;
	SERIAL* serial;
	MAINIO* mainio;
	SUBIO* subio;
	
	MainSubBridge main_sub_bridge;
	uint8_t sub_rom[0x2000];
	uint8_t sub_ram[0x0800];
	
public:
	VM(EMU* parent_emu);
	~VM();
	
	void reset();
	void run();
	void update_config();
	double get_frame_rate()
	{
		return FRAMES_PER_SEC;
	}

	void initialize_sound(int rate, int samples);
	uint16_t* create_sound(int* extra_frames);
#ifdef USE_SOUND_VOLUME
	void set_sound_device_volume(int ch, int decibel_l, int decibel_r);
#endif

#ifdef USE_SOCKET
	void notify_socket_connected(int ch);
	void notify_socket_disconnected(int ch);
	uint8_t* get_socket_send_buffer(int ch, int* size);
	void inc_socket_send_buffer_ptr(int ch, int size);
	uint8_t* get_socket_recv_buffer0(int ch, int* size0, int* size1);
	uint8_t* get_socket_recv_buffer1(int ch);
	void inc_socket_recv_buffer_ptr(int ch, int size);
#endif
	
#ifdef USE_DEBUGGER
	DEVICE* get_cpu(int index);
#endif
	
	void draw_screen();
	void key_down(int code, bool repeat);
	void key_up(int code);
	bool get_caps_locked();
	bool get_kana_locked();
	bool process_state(FILEIO* state_fio, bool loading);
	void open_floppy_disk(int drv, const _TCHAR *file_path, int bank);
	void close_floppy_disk(int drv);
	bool is_floppy_disk_inserted(int drv);
	void is_floppy_disk_protected(int drv, bool value);
	bool is_floppy_disk_protected(int drv);
	uint32_t is_floppy_disk_accessed();
	bool is_frame_skippable();
	
	DEVICE* get_device(int id);
	
	MainSubBridge& get_main_sub_bridge()
	{
		return main_sub_bridge;
	}
	const MainSubBridge& get_main_sub_bridge() const
	{
		return main_sub_bridge;
	}
};

#endif
