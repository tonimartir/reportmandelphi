unit dmtximage;
(**
 * libdmtx - Data Matrix Encoding/Decoding Library
 * Copyright 2008, 2009 Mike Laughton. All rights reserved.
 * Copyright 2012-2016 Vadim A. Misbakh-Soloviov. All rights reserved.
 *
 * See LICENSE file in the main project directory for full
 * terms of use and distribution.
 *
 * Contact:
 * Vadim A. Misbakh-Soloviov <dmtx@mva.name>
 * Mike Laughton <mike@dragonflylogic.com>
 *
 * \file dmtximage.c
 * \brief Image handling
 *)
(**
 * libdmtx stores image data as a large one-dimensional array of packed pixels,
 * reading from the array when scanning barcodes and writing to it when creating
 * a barcode. Beyond this interaction the calling program is responsible for
 * populating and dispatching pixels between the image array and the outside
 * world, whether that means loading an image from a file, acquiring camera
 * input, displaying output to a screen, saving to disk, etc...
 *
 * By default, libdmtx treats the first pixel of an image array as the top-left
 * corner of the physical image, with the final pixel landing at the bottom-
 * right. However, if mapping a pixel buffer this way produces an inverted
 * image the calling program can specify DmtxFlipY at image creation time to
 * remove the inversion. This has a negligible effect on performance since it
 * only modifies the pixel mapping math, and does not alter any pixel data.
 *
 * Regardless of how an image is stored internally, all libdmtx functions
 * consider coordinate (0,0) to mathematically represent the bottom-left pixel
 * location of an image using a right-handed coordinate system.
 *
 *                (0,HEIGHT-1)        (WIDTH-1,HEIGHT-1)
 *
 *          array pos = 0,1,2,3,...-----------+
 *                      |                     |
 *                      |                     |
 *                      |       libdmtx       |
 *                      |        image        |
 *                      |     coordinates     |
 *                      |                     |
 *                      |                     |
 *                      +---------...,N-2,N-1,N = array pos
 *
 *                    (0,0)              (WIDTH-1,0)
 *
 * Notes:
 *   - OpenGL pixel arrays obtained with glReadPixels() are stored
 *     bottom-to-top; use DmtxFlipY
 *   - Many popular image formats (e.g., PNG, GIF) store rows
 *     top-to-bottom; use DmtxFlipNone
 *)

interface

uses
  dmtx;

function dmtxImageCreate(pxl: pbyte;  width, height: integer;  pack: DmtxPackOrder): pDmtxImage;
function dmtxImageDestroy(var img: pDmtxImage): DmtxPassFail;
function GetBitsPerPixel(pack: DmtxPackOrder): integer;
function dmtxImageSetProp(img: pDmtxImage;  prop: DmtxProperty;  value: integer): DmtxPassFail;
function dmtxImageGetProp(img: pDmtxImage;  prop: DmtxProperty): integer;
function dmtxImageGetPixelValue(img: pDmtxImage;  x, y: integer;  channel: integer;  value: pinteger): DmtxPassFail;
function dmtxImageSetPixelValue(img: pDmtxImage;  x, y: integer;  channel: integer;  value: integer): DmtxPassFail;

implementation

function GetBitsPerPixel(pack: DmtxPackOrder): integer;
begin
  case pack of
    DmtxPack1bppK:
      Result := 1;
    DmtxPack8bppK:
      Result := 8;
    DmtxPack16bppRGB,
    DmtxPack16bppRGBX,
    DmtxPack16bppXRGB,
    DmtxPack16bppBGR,
    DmtxPack16bppBGRX,
    DmtxPack16bppXBGR,
    DmtxPack16bppYCbCr:
      Result := 16;
    DmtxPack24bppRGB,
    DmtxPack24bppBGR,
    DmtxPack24bppYCbCr:
      Result := 24;
    DmtxPack32bppRGBX,
    DmtxPack32bppXRGB,
    DmtxPack32bppBGRX,
    DmtxPack32bppXBGR,
    DmtxPack32bppCMYK:
      Result := 32;
    else
      result:=DmtxUndefined;
  end;{case}
end;

function dmtxImageSetChannel(img: pDmtxImage;  channelStart: integer;  bitsPerChannel: integer): DmtxPassFail;
begin
  if img^.channelCount>=4 (* IMAGE_MAX_CHANNEL *) then
    Result := DmtxFail
  else begin
    (* New channel extends beyond pixel data *)
    (* if(channelStart + bitsPerChannel > img->bitsPerPixel)
        return DmtxFail; *)
    img^.bitsPerChannel[img^.channelCount] := bitsPerChannel;
    img^.channelStart[img^.channelCount] := channelStart;
    Inc(img^.channelCount);

    Result := DmtxPass;
  end;
end;

function dmtxImageCreate(pxl: pbyte;  width, height: integer;  pack: DmtxPackOrder): pDmtxImage;
begin
  Result := nil;
  if (pxl=nil) or (width<1) or (height<1) then Exit;

  Result := ccalloc(1,sizeof(tDmtxImage));
  if Result=nil then Exit;

  Result^.pxl := pxl;
  Result^.width := width;
  Result^.height := height;
  Result^.pixelPacking := pack;
  Result^.bitsPerPixel := GetBitsPerPixel(pack);
  Result^.bytesPerPixel := Result^.bitsPerPixel div 8;
  Result^.rowPadBytes := 0;
  Result^.rowSizeBytes := Result^.width*Result^.bytesPerPixel + Result^.rowPadBytes;
  Result^.imageFlip := ord(DmtxFlipNone);
  Result^.channelCount := 0; (* Leave channelStart[] and bitsPerChannel[] with zeros from calloc *)

  case pack of
    DmtxPackCustom:
      begin
      end;
    DmtxPack1bppK:
      begin
      dmtxImageSetChannel(Result,0,1);
      (* unsupported packing order *)
      Exit(nil);
      end;
    DmtxPack8bppK:
      begin
      dmtxImageSetChannel(Result,0,8);
      end;
    DmtxPack16bppRGB,
    DmtxPack16bppBGR,
    DmtxPack16bppYCbCr:
      begin
      dmtxImageSetChannel(Result,0,5);
      dmtxImageSetChannel(Result,5,5);
      dmtxImageSetChannel(Result,10,5);
      end;
    DmtxPack24bppRGB,
    DmtxPack24bppBGR,
    DmtxPack24bppYCbCr,
    DmtxPack32bppRGBX,
    DmtxPack32bppBGRX:
      begin
      dmtxImageSetChannel(Result,0,8);
      dmtxImageSetChannel(Result,8,8);
      dmtxImageSetChannel(Result,16,8);
      end;
    DmtxPack16bppRGBX,
    DmtxPack16bppBGRX:
      begin
      dmtxImageSetChannel(Result,0,5);
      dmtxImageSetChannel(Result,5,5);
      dmtxImageSetChannel(Result,10,5);
      end;
    DmtxPack16bppXRGB,
    DmtxPack16bppXBGR:
      begin
      dmtxImageSetChannel(Result,1,5);
      dmtxImageSetChannel(Result,6,5);
      dmtxImageSetChannel(Result,11,5);
      end;
    DmtxPack32bppXRGB,
    DmtxPack32bppXBGR:
      begin
      dmtxImageSetChannel(Result,8,8);
      dmtxImageSetChannel(Result,16,8);
      dmtxImageSetChannel(Result,24,8);
      end;
    DmtxPack32bppCMYK:
      begin
      dmtxImageSetChannel(Result,0,8);
      dmtxImageSetChannel(Result,8,8);
      dmtxImageSetChannel(Result,16,8);
      dmtxImageSetChannel(Result,24,8);
      end;
    else
      Result := nil;
  end;{case}
end;

(**
 * \brief  Free libdmtx image memory
 * \param  img pointer to img location
 * \return DmtxFail | DmtxPass
 *)
function dmtxImageDestroy(var img: pDmtxImage): DmtxPassFail;
begin
  if img = nil then
    Result := DmtxFail
  else begin
    cfree(img);
    img := nil;
    Result := DmtxPass;
  end;
end;

(**
 * \brief  Set image property
 * \param  img pointer to image
 * \return image width
 *)
function dmtxImageSetProp(img: pDmtxImage;  prop: DmtxProperty;  value: integer): DmtxPassFail;
begin
  if img = nil then
    Result := DmtxFail
  else begin
    case prop of
      DmtxPropRowPadBytes:
        begin
        img^.rowPadBytes := value;
        img^.rowSizeBytes := img^.width*(img^.bitsPerPixel div 8) + img^.rowPadBytes;
        end;
      DmtxPropImageFlip:
        begin
        img^.imageFlip:= value;
        end;
    end;{case}
    Result := DmtxPass;
  end;
end;

(**
 * \brief  Get image width
 * \param  img pointer to image
 * \return image width
 *)
function dmtxImageGetProp(img: pDmtxImage;  prop: DmtxProperty): integer;
begin
  if img = nil then
    Result := DmtxUndefined
  else
    case prop of
      DmtxPropWidth:
        Result := img^.width;
      DmtxPropHeight:
        Result := img^.height;
      DmtxPropPixelPacking:
        Result := ord(img^.pixelPacking);
      DmtxPropBitsPerPixel:
        Result := img^.bitsPerPixel;
      DmtxPropBytesPerPixel:
        Result := img^.bytesPerPixel;
      DmtxPropRowPadBytes:
        Result := img^.rowPadBytes;
      DmtxPropRowSizeBytes:
        Result := img^.rowSizeBytes;
      DmtxPropImageFlip:
        Result := ord(img^.imageFlip);
      DmtxPropChannelCount:
        Result := img^.channelCount;
      else
        Result := DmtxUndefined;
  end;{case}
end;

(**
 * \brief  Test whether image contains a coordinate expressed in integers
 * \param  img
 * \param  margin width
 * \param  x coordinate
 * \param  y coordinate
 * \return DmtxTrue | DmtxFalse
 *)
function dmtxImageContainsInt(img: pDmtxImage;  margin: integer;  x, y: integer): DmtxBoolean;
begin
  assert(img<>nil);
  Result := (x-margin>=0) and (x+margin<img^.width) and (y-margin>=0) and (y+margin<img^.height);
end;

(**
 * \brief  Test whether image contains a coordinate expressed in floating points
 * \param  img
 * \param  x coordinate
 * \param  y coordinate
 * \return DmtxTrue | DmtxFalse
 *)
function dmtxImageContainsFloat(img: pDmtxImage;  x, y: double): DmtxBoolean;
begin
  assert(img<>nil);
  Result := (x>=0) and (x<img^.width) and (y>=0) and (y<img^.height);
end;

(**
 * \brief  Returns pixel offset for image
 * \param  img
 * \param  x coordinate
 * \param  y coordinate
 * \return pixel byte offset
 *)
function dmtxImageGetByteOffset(img: pDmtxImage;  x, y: integer): integer;
begin
  assert(img<>nil);
  assert((img^.imageFlip and ord(DmtxFlipX))=0); (* DmtxFlipX is not an option *)

  if not dmtxImageContainsInt(img,0,x,y) then
    Result := DmtxUndefined
  else if (img^.imageFlip and ord(DmtxFlipY)) <> 0 then
    Result := y*img^.rowSizeBytes + x*img^.bytesPerPixel
  else
    Result := (img^.height-y-1)*img^.rowSizeBytes + x*img^.bytesPerPixel;
end;


function dmtxImageGetPixelValue(img: pDmtxImage;  x, y: integer;  channel: integer;  value: pinteger): DmtxPassFail;
var
  offset: integer;
begin
  assert(img<>nil);
  assert(channel<img^.channelCount); 
  offset := dmtxImageGetByteOffset(img,x,y);
  if offset=DmtxUndefined then
    Result := DmtxFail
  else begin
    case img^.bitsPerChannel[channel] of
      1:
        (*       assert(img->bitsPerPixel == 1);
                 mask = 0x01 << (7 - offset%8);
                 *value = (img->pxl[offset/8] & mask) ? 255 : 0; *)
        ;
      5:
        (* XXX might be expensive if we want to scale perfect 0-255 range *)
        (*       assert(img->bitsPerPixel == 16);
                 pixelPtr = img->pxl + (offset * (img->bitsPerPixel/8));
                 pixelValue = ( *pixelPtr << 8) | ( *(pixelPtr+1));
                 bitShift = img->bitsPerPixel - 5 - img->channelStart[channel];
                 mask = 0x1f << bitShift;
                 *value = (((pixelValue & mask) >> bitShift) << 3); *)
        ;
      8:
        begin
        assert(img^.channelStart[channel] mod 8=0);
        assert(img^.bitsPerPixel mod 8=0);
        value^ := img^.pxl[offset+channel];
        end;
    end;{case}
    Result := DmtxPass;
  end;
end;

function dmtxImageSetPixelValue(img: pDmtxImage;  x, y: integer;  channel: integer;  value: integer): DmtxPassFail;
var
  offset: integer;
begin
  assert(img<>nil);
  assert(channel<img^.channelCount); 
  offset := dmtxImageGetByteOffset(img,x,y);
  if offset=DmtxUndefined then
    Result := DmtxFail
  else begin
    case img^.bitsPerChannel[channel] of
      1:
      (*       assert(img->bitsPerPixel == 1);
               mask = 0x01 << (7 - offset%8);
               *value = (img->pxl[offset/8] & mask) ? 255 : 0; *)
        ;
      5:
      (* XXX might be expensive if we want to scale perfect 0-255 range *)
      (*       assert(img->bitsPerPixel == 16);
               pixelPtr = img->pxl + (offset * (img->bitsPerPixel/8));
               pixelValue = ( *pixelPtr << 8) | ( *(pixelPtr+1));
               bitShift = img->bitsPerPixel - 5 - img->channelStart[channel];
               mask = 0x1f << bitShift;
               *value = (((pixelValue & mask) >> bitShift) << 3); *)
        ;
      8:
        begin
        assert(img^.channelStart[channel] mod 8=0);
        assert(img^.bitsPerPixel mod 8=0);
        img^.pxl[offset+channel] := value;
        end;
    end;{case}
    Result:= DmtxPass;
  end;
end;

end.
