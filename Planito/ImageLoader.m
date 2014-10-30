//
//  ImageLoader.m
//  Planito
//
//  Created by Vitaliy Pronkin on 5.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "ImageLoader.h"
#include "jpeglib.h"
#include "png.h"

@interface ImageLoader ()
-(BOOL) _loadJPEG;
-(BOOL) _loadPNG;
@end

@implementation ImageLoader

static void jpeg_ErrorExit(j_common_ptr cinfo)
{
	//jpeg_destroy (cinfo);
	longjmp (((ImageLoader*)cinfo->client_data)->JpegJumpBuffer, 1);
}

static void png_error_func(png_structp png_ptr, png_const_charp message)
{
	longjmp(png_jmpbuf(png_ptr), 1);
}

static void png_read(png_structp png_ptr, png_bytep data, png_size_t length)
{
    ImageLoader *self = png_get_io_ptr(png_ptr);
    
    unsigned long rem = [self->srcdata length] - self->srcpos;
    if (length > rem)
        length = rem;
    
    memcpy(data, [self->srcdata bytes]+self->srcpos, length);
    self->srcpos += length;
}

-(ImageLoader*) initWithFile: (NSString*)filepath
{
    if (self=[super init])
    {
        srcf = fopen([filepath fileSystemRepresentation], "rb");
    }
    
    return self;
}

-(ImageLoader*) initWithData: (NSData*)data
{
    if (self=[super init])
    {
        srcdata = data;
    }
    
    return self;
}

-(BOOL) load
{
    if (!format)
    {
        unsigned char *b = NULL, _b[8];
        if (srcf)
        {
            fread(_b, 8, 1, srcf);
            rewind(srcf);
            b = _b;
        }
        else if (srcdata)
            b = [srcdata bytes];

        if (b && b[0] == 0xFF && b[1] == 0xD8)
            format = 1;
        else if (png_check_sig(b, 8))
            format = 2;
    }

    if (format == 1)
        return [self _loadJPEG];
    
    if (format == 2)
        return [self _loadPNG];

    return NO;
}

-(BOOL) _loadJPEG
{
	struct jpeg_error_mgr Error;
	struct jpeg_decompress_struct JpegInfo;
    
    JpegInfo.client_data = self;
    
	JpegInfo.err = jpeg_std_error(&Error);
	Error.error_exit = jpeg_ErrorExit;
    
	if (setjmp(JpegJumpBuffer))
    {
        jpeg_destroy_decompress(&JpegInfo);
        
        if (imgdata)
        {
            free(imgdata);
            imgdata = NULL;
        }
        
        return NO;
    }

	jpeg_create_decompress(&JpegInfo);
        
    if (srcf)
        jpeg_stdio_src(&JpegInfo, srcf);
    else if (srcdata)
        jpeg_mem_src(&JpegInfo, [srcdata bytes], [srcdata length]);
    
    jpeg_read_header(&JpegInfo, 1);
    
    unsigned char *TempPtr[1];
    unsigned int Returned;
    
    JpegInfo.out_color_space = JCS_RGB;
    hasAlpha = NO;
    
    jpeg_start_decompress(&JpegInfo);
    
    imgdata = malloc(JpegInfo.output_width * JpegInfo.output_height * 4);
    
    TempPtr[0] = imgdata;
    while (JpegInfo.output_scanline < JpegInfo.output_height)
    {
        Returned = jpeg_read_scanlines(&JpegInfo, TempPtr, 1);
        TempPtr[0] += JpegInfo.output_width * 4;
        if (Returned == 0)
            break;
    }
    
    jpeg_finish_decompress(&JpegInfo);
    jpeg_destroy_decompress(&JpegInfo);

    return YES;
}

-(BOOL) _loadPNG
{
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    png_bytepp row_pointers = NULL;
    
    png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, png_error_func, NULL);
	if (!png_ptr)
		return NO;
    
	info_ptr = png_create_info_struct(png_ptr);
	if (!info_ptr)
    {
		png_destroy_read_struct(&png_ptr, NULL, NULL);
		return NO;
	}
        
	if (setjmp(png_jmpbuf(png_ptr)))
    {
		png_destroy_read_struct(&png_ptr, &info_ptr, NULL);

        if (imgdata)
        {
            free (imgdata);
            imgdata = NULL;
        }
        if (row_pointers)
            free (row_pointers);
        
		return NO;
	}
    
    if (srcf)
        png_init_io(png_ptr, srcf);
    else if (srcdata)
        png_set_read_fn(png_ptr, self, png_read);
    
	png_read_info(png_ptr, info_ptr);

    png_uint_32 width, height; // Changed the type to fix AMD64 bit problems, thanks to Eric Werness
    int	bit_depth;
    int	png_color_type;
                
    png_get_IHDR(png_ptr, info_ptr, &width, &height, &bit_depth, &png_color_type, NULL, NULL, NULL);
    
    switch (png_color_type)
    {
        case PNG_COLOR_TYPE_GRAY:
        case PNG_COLOR_TYPE_GRAY_ALPHA:
            png_set_gray_to_rgb(png_ptr);
            png_set_strip_16(png_ptr);
            if (png_color_type != PNG_COLOR_TYPE_GRAY_ALPHA)
                if (png_get_valid(png_ptr, info_ptr, PNG_INFO_tRNS))
                {
                    png_set_tRNS_to_alpha(png_ptr);
                    hasAlpha = YES;
                }
                else
                    png_set_filler(png_ptr, 0, PNG_FILLER_AFTER);
            break;
            
        case PNG_COLOR_TYPE_PALETTE:
            png_set_palette_to_rgb(png_ptr); //changed to convert to BGR
            if (png_get_valid(png_ptr, info_ptr, PNG_INFO_tRNS))
            {
                png_set_tRNS_to_alpha(png_ptr);
                hasAlpha = YES;
            }
            else
                png_set_filler(png_ptr, 0, PNG_FILLER_AFTER);
            break;
            
        case PNG_COLOR_TYPE_RGB:
            png_set_strip_16(png_ptr);
            png_set_bgr(png_ptr);
            png_set_filler(png_ptr, 0, PNG_FILLER_AFTER);
            break;
            
        case PNG_COLOR_TYPE_RGB_ALPHA:
            png_set_strip_16(png_ptr);
            png_set_bgr(png_ptr);
            hasAlpha = YES;
            break;
            
        default: //unknown format
            png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
            return NO;
    }
    
    png_read_update_info(png_ptr, info_ptr);
    
    imgdata = malloc(width * height * 4);
    
    row_pointers = (png_bytepp)malloc(height * sizeof(png_bytep));
    for (int i = 0; i < height; i++)
        row_pointers[i] = imgdata + i * width * 4;
    
    png_read_image(png_ptr, row_pointers);
    
    free(row_pointers);
    
    png_destroy_read_struct(&png_ptr, &info_ptr, NULL);

    return YES;
}


-(void) dealloc
{
    if (srcf)
        fclose(srcf);
    
    [super dealloc];
}

@end
