
# Assembly BMP Editor

![preview](https://github.com/prxbdead/bmp-editor/blob/main/preview.png?raw=true)
This repository contains an assembly language program for editing BMP images, developed as a bonus project for my Computer Architecture course at university.

## Features

The program provides a graphical interface for displaying BMP images, specified as command-line arguments, supporting both 256-color and true color (24/32-bit) images. The images can also be compressed.

### Graphical Interface Functions

The following functionalities are available through buttons on the graphical interface:

- **Cropping:** Allows the user to crop the image using the mouse.
- **Resizing:** Supports nearest-neighbor resizing using the mouse.
- **Gaussian Blur:** Applies a Gaussian blur effect to the image.
- **Saving the Edited Image:** The edited image can be saved in both true color and 256-color formats (with conversion from true color).
- **Compressing and Saving the Edited Image:** The edited image can be saved with RLE compression in both 256-color and true color formats (with separate compression for RGB color attributes in the true color case).

## Build Process

To build the program, follow these steps:

1. Navigate to the build directory:
    ```sh
    cd build
    ```

2. Assemble the program using `nasm`:
    ```sh
    wine nasm.exe -f win32 ../bitmap.asm
    ```

3. Link the object file using `nlink`:
    ```sh
    wine nlink.exe ../bitmap.obj -lio -lgfx -lutil -o bitmap.exe
    ```

## Usage

To run the program, provide the BMP image file as a command-line argument. The graphical interface will then allow you to perform various editing functions on the image.

## Development

This project was created to deepen my understanding of computer architecture and low-level programming. It showcases the use of assembly language for handling complex image processing tasks.

Feel free to explore the code and experiment with the functionalities!

