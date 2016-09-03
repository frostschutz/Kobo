// +build linux,arm

// defs2go fb.h
// CC=arm-gcc GOOS=linux GOARCH=arm cgo -godefs

package main

const FB_MAX = 0x20
const FBIOGET_VSCREENINFO = 0x4600
const FBIOPUT_VSCREENINFO = 0x4601
const FBIOGET_FSCREENINFO = 0x4602
const FBIOGETCMAP = 0x4604
const FBIOPUTCMAP = 0x4605
const FBIOPAN_DISPLAY = 0x4606
const FBIO_CURSOR = 0xc0484608
const FBIOGET_CON2FBMAP = 0x460f
const FBIOPUT_CON2FBMAP = 0x4610
const FBIOBLANK = 0x4611
const FBIOGET_VBLANK = 0x80204612
const FBIO_ALLOC = 0x4613
const FBIO_FREE = 0x4614
const FBIOGET_GLYPH = 0x4615
const FBIOGET_HWCINFO = 0x4616
const FBIOPUT_MODEINFO = 0x4617
const FBIOGET_DISPINFO = 0x4618
const FBIO_WAITFORVSYNC = 0x40044620
const FB_TYPE_PACKED_PIXELS = 0x0
const FB_TYPE_PLANES = 0x1
const FB_TYPE_INTERLEAVED_PLANES = 0x2
const FB_TYPE_TEXT = 0x3
const FB_TYPE_VGA_PLANES = 0x4
const FB_TYPE_FOURCC = 0x5
const FB_AUX_TEXT_MDA = 0x0
const FB_AUX_TEXT_CGA = 0x1
const FB_AUX_TEXT_S3_MMIO = 0x2
const FB_AUX_TEXT_MGA_STEP16 = 0x3
const FB_AUX_TEXT_MGA_STEP8 = 0x4
const FB_AUX_TEXT_SVGA_GROUP = 0x8
const FB_AUX_TEXT_SVGA_MASK = 0x7
const FB_AUX_TEXT_SVGA_STEP2 = 0x8
const FB_AUX_TEXT_SVGA_STEP4 = 0x9
const FB_AUX_TEXT_SVGA_STEP8 = 0xa
const FB_AUX_TEXT_SVGA_STEP16 = 0xb
const FB_AUX_TEXT_SVGA_LAST = 0xf
const FB_AUX_VGA_PLANES_VGA4 = 0x0
const FB_AUX_VGA_PLANES_CFB4 = 0x1
const FB_AUX_VGA_PLANES_CFB8 = 0x2
const FB_VISUAL_MONO01 = 0x0
const FB_VISUAL_MONO10 = 0x1
const FB_VISUAL_TRUECOLOR = 0x2
const FB_VISUAL_PSEUDOCOLOR = 0x3
const FB_VISUAL_DIRECTCOLOR = 0x4
const FB_VISUAL_STATIC_PSEUDOCOLOR = 0x5
const FB_VISUAL_FOURCC = 0x6
const FB_ACCEL_NONE = 0x0
const FB_ACCEL_ATARIBLITT = 0x1
const FB_ACCEL_AMIGABLITT = 0x2
const FB_ACCEL_S3_TRIO64 = 0x3
const FB_ACCEL_NCR_77C32BLT = 0x4
const FB_ACCEL_S3_VIRGE = 0x5
const FB_ACCEL_ATI_MACH64GX = 0x6
const FB_ACCEL_DEC_TGA = 0x7
const FB_ACCEL_ATI_MACH64CT = 0x8
const FB_ACCEL_ATI_MACH64VT = 0x9
const FB_ACCEL_ATI_MACH64GT = 0xa
const FB_ACCEL_SUN_CREATOR = 0xb
const FB_ACCEL_SUN_CGSIX = 0xc
const FB_ACCEL_SUN_LEO = 0xd
const FB_ACCEL_IMS_TWINTURBO = 0xe
const FB_ACCEL_3DLABS_PERMEDIA2 = 0xf
const FB_ACCEL_MATROX_MGA2064W = 0x10
const FB_ACCEL_MATROX_MGA1064SG = 0x11
const FB_ACCEL_MATROX_MGA2164W = 0x12
const FB_ACCEL_MATROX_MGA2164W_AGP = 0x13
const FB_ACCEL_MATROX_MGAG100 = 0x14
const FB_ACCEL_MATROX_MGAG200 = 0x15
const FB_ACCEL_SUN_CG14 = 0x16
const FB_ACCEL_SUN_BWTWO = 0x17
const FB_ACCEL_SUN_CGTHREE = 0x18
const FB_ACCEL_SUN_TCX = 0x19
const FB_ACCEL_MATROX_MGAG400 = 0x1a
const FB_ACCEL_NV3 = 0x1b
const FB_ACCEL_NV4 = 0x1c
const FB_ACCEL_NV5 = 0x1d
const FB_ACCEL_CT_6555x = 0x1e
const FB_ACCEL_3DFX_BANSHEE = 0x1f
const FB_ACCEL_ATI_RAGE128 = 0x20
const FB_ACCEL_IGS_CYBER2000 = 0x21
const FB_ACCEL_IGS_CYBER2010 = 0x22
const FB_ACCEL_IGS_CYBER5000 = 0x23
const FB_ACCEL_SIS_GLAMOUR = 0x24
const FB_ACCEL_3DLABS_PERMEDIA3 = 0x25
const FB_ACCEL_ATI_RADEON = 0x26
const FB_ACCEL_I810 = 0x27
const FB_ACCEL_SIS_GLAMOUR_2 = 0x28
const FB_ACCEL_SIS_XABRE = 0x29
const FB_ACCEL_I830 = 0x2a
const FB_ACCEL_NV_10 = 0x2b
const FB_ACCEL_NV_20 = 0x2c
const FB_ACCEL_NV_30 = 0x2d
const FB_ACCEL_NV_40 = 0x2e
const FB_ACCEL_XGI_VOLARI_V = 0x2f
const FB_ACCEL_XGI_VOLARI_Z = 0x30
const FB_ACCEL_OMAP1610 = 0x31
const FB_ACCEL_TRIDENT_TGUI = 0x32
const FB_ACCEL_TRIDENT_3DIMAGE = 0x33
const FB_ACCEL_TRIDENT_BLADE3D = 0x34
const FB_ACCEL_TRIDENT_BLADEXP = 0x35
const FB_ACCEL_CIRRUS_ALPINE = 0x35
const FB_ACCEL_NEOMAGIC_NM2070 = 0x5a
const FB_ACCEL_NEOMAGIC_NM2090 = 0x5b
const FB_ACCEL_NEOMAGIC_NM2093 = 0x5c
const FB_ACCEL_NEOMAGIC_NM2097 = 0x5d
const FB_ACCEL_NEOMAGIC_NM2160 = 0x5e
const FB_ACCEL_NEOMAGIC_NM2200 = 0x5f
const FB_ACCEL_NEOMAGIC_NM2230 = 0x60
const FB_ACCEL_NEOMAGIC_NM2360 = 0x61
const FB_ACCEL_NEOMAGIC_NM2380 = 0x62
const FB_ACCEL_PXA3XX = 0x63
const FB_ACCEL_SAVAGE4 = 0x80
const FB_ACCEL_SAVAGE3D = 0x81
const FB_ACCEL_SAVAGE3D_MV = 0x82
const FB_ACCEL_SAVAGE2000 = 0x83
const FB_ACCEL_SAVAGE_MX_MV = 0x84
const FB_ACCEL_SAVAGE_MX = 0x85
const FB_ACCEL_SAVAGE_IX_MV = 0x86
const FB_ACCEL_SAVAGE_IX = 0x87
const FB_ACCEL_PROSAVAGE_PM = 0x88
const FB_ACCEL_PROSAVAGE_KM = 0x89
const FB_ACCEL_S3TWISTER_P = 0x8a
const FB_ACCEL_S3TWISTER_K = 0x8b
const FB_ACCEL_SUPERSAVAGE = 0x8c
const FB_ACCEL_PROSAVAGE_DDR = 0x8d
const FB_ACCEL_PROSAVAGE_DDRK = 0x8e
const FB_ACCEL_PUV3_UNIGFX = 0xa0
const FB_CAP_FOURCC = 0x1

type fb_fix_screeninfo struct {
	Id           [16]uint8
	Smem_start   uint32
	Smem_len     uint32
	Type         uint32
	Type_aux     uint32
	Visual       uint32
	Xpanstep     uint16
	Ypanstep     uint16
	Ywrapstep    uint16
	Pad_cgo_0    [2]byte
	Line_length  uint32
	Mmio_start   uint32
	Mmio_len     uint32
	Accel        uint32
	Capabilities uint16
	Reserved     [2]uint16
	Pad_cgo_1    [2]byte
}
type fb_bitfield struct {
	Offset uint32
	Length uint32
	Right  uint32
}

const FB_NONSTD_HAM = 0x1
const FB_NONSTD_REV_PIX_IN_B = 0x2
const FB_ACTIVATE_NOW = 0x0
const FB_ACTIVATE_NXTOPEN = 0x1
const FB_ACTIVATE_TEST = 0x2
const FB_ACTIVATE_MASK = 0xf
const FB_ACTIVATE_VBL = 0x10
const FB_CHANGE_CMAP_VBL = 0x20
const FB_ACTIVATE_ALL = 0x40
const FB_ACTIVATE_FORCE = 0x80
const FB_ACTIVATE_INV_MODE = 0x100
const FB_ACCELF_TEXT = 0x1
const FB_SYNC_HOR_HIGH_ACT = 0x1
const FB_SYNC_VERT_HIGH_ACT = 0x2
const FB_SYNC_EXT = 0x4
const FB_SYNC_COMP_HIGH_ACT = 0x8
const FB_SYNC_BROADCAST = 0x10
const FB_SYNC_ON_GREEN = 0x20
const FB_VMODE_NONINTERLACED = 0x0
const FB_VMODE_INTERLACED = 0x1
const FB_VMODE_DOUBLE = 0x2
const FB_VMODE_ODD_FLD_FIRST = 0x4
const FB_VMODE_MASK = 0xff
const FB_VMODE_YWRAP = 0x100
const FB_VMODE_SMOOTH_XPAN = 0x200
const FB_VMODE_CONUPDATE = 0x200
const FB_ROTATE_UR = 0x0
const FB_ROTATE_CW = 0x1
const FB_ROTATE_UD = 0x2
const FB_ROTATE_CCW = 0x3

type fb_var_screeninfo struct {
	Xres           uint32
	Yres           uint32
	Xres_virtual   uint32
	Yres_virtual   uint32
	Xoffset        uint32
	Yoffset        uint32
	Bits_per_pixel uint32
	Grayscale      uint32
	Red            fb_bitfield
	Green          fb_bitfield
	Blue           fb_bitfield
	Transp         fb_bitfield
	Nonstd         uint32
	Activate       uint32
	Height         uint32
	Width          uint32
	Accel_flags    uint32
	Pixclock       uint32
	Left_margin    uint32
	Right_margin   uint32
	Upper_margin   uint32
	Lower_margin   uint32
	Hsync_len      uint32
	Vsync_len      uint32
	Sync           uint32
	Vmode          uint32
	Rotate         uint32
	Colorspace     uint32
	Reserved       [4]uint32
}
type fb_cmap struct {
	Start  uint32
	Len    uint32
	Red    *uint16
	Green  *uint16
	Blue   *uint16
	Transp *uint16
}
type fb_con2fbmap struct {
	Console     uint32
	Framebuffer uint32
}

const VESA_NO_BLANKING = 0x0
const VESA_VSYNC_SUSPEND = 0x1
const VESA_HSYNC_SUSPEND = 0x2
const VESA_POWERDOWN = 0x3
const FB_VBLANK_VBLANKING = 0x1
const FB_VBLANK_HBLANKING = 0x2
const FB_VBLANK_HAVE_VBLANK = 0x4
const FB_VBLANK_HAVE_HBLANK = 0x8
const FB_VBLANK_HAVE_COUNT = 0x10
const FB_VBLANK_HAVE_VCOUNT = 0x20
const FB_VBLANK_HAVE_HCOUNT = 0x40
const FB_VBLANK_VSYNCING = 0x80
const FB_VBLANK_HAVE_VSYNC = 0x100

type fb_vblank struct {
	Flags    uint32
	Count    uint32
	Vcount   uint32
	Hcount   uint32
	Reserved [4]uint32
}

const ROP_COPY = 0x0
const ROP_XOR = 0x1

type fb_copyarea struct {
	Dx     uint32
	Dy     uint32
	Width  uint32
	Height uint32
	Sx     uint32
	Sy     uint32
}
type fb_fillrect struct {
	Dx     uint32
	Dy     uint32
	Width  uint32
	Height uint32
	Color  uint32
	Rop    uint32
}
type fb_image struct {
	Dx        uint32
	Dy        uint32
	Width     uint32
	Height    uint32
	Fg_color  uint32
	Bg_color  uint32
	Depth     uint8
	Pad_cgo_0 [3]byte
	Data      *uint8
	Cmap      fb_cmap
}

const FB_CUR_SETIMAGE = 0x1
const FB_CUR_SETPOS = 0x2
const FB_CUR_SETHOT = 0x4
const FB_CUR_SETCMAP = 0x8
const FB_CUR_SETSHAPE = 0x10
const FB_CUR_SETSIZE = 0x20
const FB_CUR_SETALL = 0xff

type fbcurpos struct {
	X uint16
	Y uint16
}
type fb_cursor struct {
	Set       uint16
	Enable    uint16
	Rop       uint16
	Pad_cgo_0 [2]byte
	Mask      *uint8
	Hot       fbcurpos
	Image     fb_image
}

const FB_BACKLIGHT_LEVELS = 0x80
const FB_BACKLIGHT_MAX = 0xff
