# VerilogOven
Programmed DE10-Lite Intel FPGA board to have the same functionality as an oven

## Functionality
The functionality includes 4 display options that can be triggered by 00, 01, 10, 10 using Pins 9 and 8 respectively:
* (00) Displaying a clock, that begins a timer (mm:ss) from the time that the fpga is powered on.
* (01) Display the current oven teperature (___F).
    * The oven spec are set to increase the temperature by 2F every second.
    * The oven will cool off by 1F every two seconds.
* (10) Displays the timer you wish to cook for.
    * When the preheat temerature is reached this timer will begin and count down.
    * When the timer reaches 0, LED2 will turn on.
* (11) Displays the temperature you wish to preheat.
    * This value is set to a default of 300F but can be increased or decreased using Key 0 or Key 1 respectivly. The temperature will increment/decrement by 50F.
    * When this value is reached by the oven LED1 will turn on.
    * A maximum preheat value is set to 500F.

The oven may be turned on or off at any time using SW0.

## Technical Details
The .qsf file is made for DE10-Lite instrument 10M50DAF484C7G
Quartus Prime Lite (19.1) was used for compiliing, running, and testing. 
