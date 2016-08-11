// defs2go mxcfb.h
// CC=arm-gcc GOOS=linux GOARCH=arm cgo -godefs

package main

const FB_SYNC_OE_LOW_ACT = 0x80000000
const FB_SYNC_CLK_LAT_FALL = 0x40000000
const FB_SYNC_DATA_INVERT = 0x20000000
const FB_SYNC_CLK_IDLE_EN = 0x10000000
const FB_SYNC_SHARP_MODE = 0x8000000
const FB_SYNC_SWAP_RGB = 0x4000000

type mxcfb_gbl_alpha struct {
	Enable int32
	Alpha  int32
}
type mxcfb_loc_alpha struct {
	Enable    int32
	In_pixel  int32
	Phy_addr0 uint32
	Phy_addr1 uint32
}
type mxcfb_color_key struct {
	Enable int32
	Key    uint32
}
type mxcfb_pos struct {
	X uint16
	Y uint16
}
type mxcfb_gamma struct {
	Enable int32
	Constk [16]int32
	Slopek [16]int32
}
type mxcfb_rect struct {
	Top    uint32
	Left   uint32
	Width  uint32
	Height uint32
}

const GRAYSCALE_8BIT = 0x1
const GRAYSCALE_8BIT_INVERTED = 0x2
const AUTO_UPDATE_MODE_REGION_MODE = 0x0
const AUTO_UPDATE_MODE_AUTOMATIC_MODE = 0x1
const UPDATE_SCHEME_SNAPSHOT = 0x0
const UPDATE_SCHEME_QUEUE = 0x1
const UPDATE_SCHEME_QUEUE_AND_MERGE = 0x2
const UPDATE_MODE_PARTIAL = 0x0
const UPDATE_MODE_FULL = 0x1
const WAVEFORM_MODE_AUTO = 0x101
const TEMP_USE_AMBIENT = 0x1000
const EPDC_FLAG_ENABLE_INVERSION = 0x1
const EPDC_FLAG_FORCE_MONOCHROME = 0x2
const EPDC_FLAG_USE_ALT_BUFFER = 0x100
const FB_POWERDOWN_DISABLE = -0x1
const FB_TEMP_AUTO_UPDATE_DISABLE = -0x1

type mxcfb_alt_buffer_data struct {
	Virt_addr         *byte
	Phys_addr         uint32
	Width             uint32
	Height            uint32
	Alt_update_region mxcfb_rect
}
type mxcfb_update_data struct {
	Update_region   mxcfb_rect
	Waveform_mode   uint32
	Update_mode     uint32
	Update_marker   uint32
	Temp            int32
	Flags           int32
	Alt_buffer_data mxcfb_alt_buffer_data
}
type mxcfb_waveform_modes struct {
	Init int32
	Du   int32
	Gc4  int32
	Gc8  int32
	Gc16 int32
	Gc32 int32
}

const MXCFB_WAIT_FOR_VSYNC = 0x40044620
const MXCFB_SET_GBL_ALPHA = 0x40084621
const MXCFB_SET_CLR_KEY = 0x40084622
const MXCFB_SET_OVERLAY_POS = 0xc0044624
const MXCFB_GET_FB_IPU_CHAN = 0x80044625
const MXCFB_SET_LOC_ALPHA = 0xc0104626
const MXCFB_SET_LOC_ALP_BUF = 0x40044627
const MXCFB_SET_GAMMA = 0x40844628
const MXCFB_GET_FB_IPU_DI = 0x80044629
const MXCFB_GET_DIFMT = 0x8004462a
const MXCFB_GET_FB_BLANK = 0x8004462b
const MXCFB_SET_DIFMT = 0x4004462c
const MXCFB_SET_WAVEFORM_MODES = 0x4018462b
const MXCFB_SET_TEMPERATURE = 0x4004462c
const MXCFB_SET_AUTO_UPDATE_MODE = 0x4004462d
const MXCFB_SEND_UPDATE = 0x4044462e
const MXCFB_WAIT_FOR_UPDATE_COMPLETE = 0x4004462f
const MXCFB_SET_PWRDOWN_DELAY = 0x40044630
const MXCFB_GET_PWRDOWN_DELAY = 0x80044631
const MXCFB_SET_UPDATE_SCHEME = 0x40044632
const MXCFB_GET_PMIC_TEMPERATURE = 0x80044632
const MXCFB_SET_BORDER_MODE = 0x80044633
const MXCFB_SET_EPD_PWR0_CTRL = 0x80044634
const MXCFB_SET_EPD_PWR2_CTRL = 0x80044635
const MXCFB_SET_TEMP_AUTO_UPDATE_PERIOD = 0x80044636
const MXCFB_SET_MERGE_ON_WAVEFORM_MISMATCH = 0x40044637

const MXCFB_REFRESH_OFF = 0
const MXCFB_REFRESH_AUTO = 1
const MXCFB_REFRESH_PARTIAL = 2
