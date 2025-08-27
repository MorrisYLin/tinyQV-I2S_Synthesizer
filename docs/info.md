<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## What it does

This peripheral outputs a I2S data stream.

## Register map

| Address | Name  | Access | Description                                                         |
|---------|-------|--------|---------------------------------------------------------------------|
| 0x00    | SCK   | R      | LSB is I2S's SCK                                                    |

## How to test

Something, something, write a few registers, then watch the I2S sound (PCM-coded data) stream out!

## External hardware

A I2S stereo decoder, like Adafruit's UDA1334A (https://learn.adafruit.com/adafruit-i2s-stereo-decoder-uda1334a/pinouts).
