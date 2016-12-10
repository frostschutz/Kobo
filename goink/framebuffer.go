package main

import (
	"image"
	"image/color"
)

// Color Model RGB565

type Pixel565 uint16

const (
	r = 5
	g = 6
	b = 5

	rshift = g + b
	gshift = b
	bshift = 0

	rmask = ((1 << r) - 1) << rshift
	gmask = ((1 << g) - 1) << gshift
	bmask = ((1 << b) - 1) << bshift
)

func (p Pixel565) RGBA() (r, g, b, a uint32) {
	r = uint32((p & rmask) >> (rshift - 3))
	r |= r << 8
	g = uint32((p & gmask) >> (gshift - 2))
	g |= g << 8
	b = uint32((p & bmask) << 3)
	b |= b << 8
	a = 0xffff
	return
}

var Model565 color.Model = color.ModelFunc(model565)

func model565(c color.Color) color.Color {
	if _, ok := c.(Pixel565); ok {
		return c
	}
	r, g, b, _ := c.RGBA()
	r >>= rshift
	g >>= gshift
	b >>= bshift
	return Pixel565(r&rmask | g&gmask | b&bmask)
}

// Image RGB565

type Fb565 struct {
	Pix    []Pixel565
	Rect   image.Rectangle
	Stride int
}

func (p *Fb565) ColorModel() color.Model { return Model565 }

func (p *Fb565) Bounds() image.Rectangle { return p.Rect }

func (p *Fb565) PixOffset(x, y int) int {
	return (y-p.Rect.Min.Y)*p.Stride + (x - p.Rect.Min.X)
}

func (p *Fb565) At(x, y int) color.Color {
	if !(image.Point{x, y}.In(p.Rect)) {
		return color.Alpha{}
	}

	return p.Pix[p.PixOffset(x, y)]
}

func (p *Fb565) Set(x, y int, c color.Color) {
	if !(image.Point{x, y}.In(p.Rect)) {
		return
	}
	p.Pix[p.PixOffset(x, y)] = Model565.Convert(c).(Pixel565)
}
