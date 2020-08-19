module Oven (input ON_OFF_INPUT,
			 input UP,
			 input DOWN,
			 input SW9,
			 input SW8,
			 input clk, 
			 output reg ON_OFF_OUTPUT,	// ON or OFF
			 output reg READY,			// Temp is ready
			 output reg DONE,				// Oven has finished cooking
			 output reg [7:0] HEX0,
			 output reg [7:0] HEX1,
			 output reg [7:0] HEX2,
			 output reg [7:0] HEX3
			);

	reg [11:0] kitchen_clock = 0;			// Up to 59 minutes and 59 seconds -- 3599 seconds -- 12 bits
	reg [11:0] kitchen_timer = 0;			// Up to 60 minutes -- 3600 seconds -- 12 bits
	
	parameter ROOM_TEMP = 65;
	parameter DEFAULT_TEMP = 300;
	parameter MAX_TEMP = 500;
	reg [8:0] oven_temp = ROOM_TEMP;			// Up to 500 -- 9 bits
	reg [8:0] preheat_temp = DEFAULT_TEMP;	// Up to 500 -- 9 bits
	reg decrease_temp = 0;

// Generate clocks
	// Frequency of this clock is 1 second
	reg one_sec_clk;
	parameter ONE_SEC = 25000000;
	reg [24:0] one_sec_count = 0;
	always @ (posedge clk) begin
		if (one_sec_count <= ONE_SEC) one_sec_count <= one_sec_count + 1;
		else begin
			one_sec_count <= 0;
			one_sec_clk <= ~one_sec_clk;
		end
	end
	
	//  This clock is used for button and switches that change states
	reg new_clk;
	parameter MAX_COUNT = 6250000;
	reg [23:0] count = 0;
	always @ (posedge clk) begin
		if (count <= MAX_COUNT) count <= count + 1;
		else begin
			count <= 0;
			new_clk <= ~new_clk;
		end
	end

// Combincational Next
	localparam OFF = 0, PREHEAT = 1, MAINTAIN = 2;
	reg [1:0] current_oven_state, next_oven_state;

	localparam SHOW_CLOCK = 0, SHOW_TEMP = 1, SET_TIMER = 2, SET_TEMP = 3;
	reg [1:0] current_display_state, next_display_state;

	localparam NONE = 0, INCREASE_TIMER = 1, DECREASE_TIMER = 2, INCREASE_TEMP = 3, DECREASE_TEMP = 4;
	reg [2:0] current_increase_decrease_state, next_increase_decrease_state;

	always @ (*) begin
		// Change oven state
		next_oven_state = current_oven_state;
		case (current_oven_state)
			OFF: if (ON_OFF_INPUT == 1) next_oven_state = PREHEAT;
			PREHEAT: begin
				if (ON_OFF_INPUT == 0) next_oven_state = OFF;
				else if (oven_temp < preheat_temp + 1 && oven_temp > preheat_temp - 1) next_oven_state = MAINTAIN;
			end
			MAINTAIN: begin
				if (ON_OFF_INPUT == 0) next_oven_state = OFF;
				else if (oven_temp > preheat_temp + 1 || oven_temp < preheat_temp - 1) next_oven_state = PREHEAT;
			end
		endcase
		
		// Change display state
		// No case needed because the next state is not dependent on current state
		if (SW9 == 0 && SW8 == 0) next_display_state = SHOW_CLOCK;
		if (SW9 == 0 && SW8 == 1) next_display_state = SHOW_TEMP;
		if (SW9 == 1 && SW8 == 0) next_display_state = SET_TIMER;
		if (SW9 == 1 && SW8 == 1) next_display_state = SET_TEMP;

		// Change state to increase or decrease timer or preheat temperature
		// No case needed because the next state is not dependent on current state
		if (SW9 == 1 && SW8 == 0) begin
			if (~UP) next_increase_decrease_state = INCREASE_TIMER;
			else if (~DOWN) next_increase_decrease_state = DECREASE_TIMER;
			else next_increase_decrease_state = NONE;
		end
		if (SW9 == 1 && SW8 == 1) begin
			if (~UP) next_increase_decrease_state = INCREASE_TEMP;
			else if (~DOWN) next_increase_decrease_state = DECREASE_TEMP;
			else next_increase_decrease_state = NONE;
		end
		if (SW9 == 0) next_increase_decrease_state = NONE;
	end
	
// FF
	// Change states, new_clk is optimized for how long a user will have to press the buttons
	always @ (posedge new_clk) begin
		current_oven_state <= next_oven_state;
		current_display_state <= next_display_state;
		current_increase_decrease_state <= next_increase_decrease_state;
	end

	// Everything in this FF will happen every second
	always @ (posedge one_sec_clk) begin
		// Change timer's appropriately
		kitchen_clock <= kitchen_clock + 1;
		if (kitchen_timer > 0 && READY == 1) kitchen_timer <= kitchen_timer - 1;
		
		// Change the timer and preheat temperatures
		// These must be in the FF because kitchen timer is being changed within the FF so using it as an 
		// input outside of FF will result in an error
		case (current_increase_decrease_state)
			INCREASE_TIMER: if (kitchen_timer <= 3570) kitchen_timer <= kitchen_timer + 30;
			DECREASE_TIMER: if (kitchen_timer >= 30) kitchen_timer <= kitchen_timer - 30;
			INCREASE_TEMP: if (preheat_temp <= 450) preheat_temp <= preheat_temp + 50;
			DECREASE_TEMP: if (preheat_temp >= 150) preheat_temp <= preheat_temp - 50;
		endcase

		// Based on the current state change the current oven temperature.
		case (current_oven_state)
			PREHEAT: begin
				ON_OFF_OUTPUT <= 1;
				READY <= 0;
				if (oven_temp < preheat_temp - 1) oven_temp <= oven_temp + 2;
				else begin
					if (decrease_temp == 0) decrease_temp <= 1;
					else begin
						oven_temp <= oven_temp - 1;
						decrease_temp <= 0;
					end
				end
			end
			MAINTAIN: begin
				ON_OFF_OUTPUT <= 1;
				READY <= 1;
				
				if (kitchen_timer == 0) DONE <= 1;
				else DONE <= 0;
				if (oven_temp == preheat_temp - 1) oven_temp <= oven_temp + 2;
				else begin
					if (decrease_temp == 0) decrease_temp <= 1;
					else begin
						oven_temp <= oven_temp - 1;
						decrease_temp <= 0;
					end
				end
			end
			OFF: begin
				ON_OFF_OUTPUT <= 0;
				READY <= 0;
				if (oven_temp > ROOM_TEMP) begin
					if (decrease_temp == 0) decrease_temp <= 1;
					else begin
						oven_temp <= oven_temp - 1;
						decrease_temp <= 0;
					end
				end
			end
		endcase			
	end

// Combinational Out
	// Select display setting
	// 0 is clock, 1 is current oven temp, 2 is cook time, 3 is preheat temp
	reg [1:0] display_setting = 0;

	reg [3:0] H3 = 0;
	reg [3:0] H2 = 0;
	reg [3:0] H1 = 0;
	reg [3:0] H0 = 0;
	
	always @ (*) begin
		// Display kitchen_clock (0)
		// Display preheat time (2)
		if (display_setting == 0 || display_setting == 2) begin
			if (display_setting  == 0) begin
				H3 = (kitchen_clock / 60) / 10;
				H2 = (kitchen_clock / 60) - (H3 * 10);
				H1 = (kitchen_clock % 60) / 10;
				H0 = (kitchen_clock % 60) - (H1 * 10);
			end
			if (display_setting == 2) begin
				H3 = (kitchen_timer / 60) / 10;
				H2 = (kitchen_timer / 60) - (H3 * 10);
				H1 = (kitchen_timer % 60) / 10;
				H0 = (kitchen_timer % 60) - (H1 * 10);
			end
			case (H3)
				0: HEX3 = 8'b11000000;			// 0
				1: HEX3 = 8'b11111001;			// 1
				2: HEX3 = 8'b10100100;			// 2
				3: HEX3 = 8'b10110000;			// 3
				4: HEX3 = 8'b10011001;			// 4
				5: HEX3 = 8'b10010010;			// 5
				6: HEX3 = 8'b10000010;			// 6
				7: HEX3 = 8'b11111000;			// 7
				8: HEX3 = 8'b10000000;			// 8
				9: HEX3 = 8'b10010000;			// 9
				default: HEX3 = 8'b10111111;	// - 
			endcase
			case (H2)
				0: HEX2 = 8'b01000000;			// 0
				1: HEX2 = 8'b01111001;			// 1
				2: HEX2 = 8'b00100100;			// 2
				3: HEX2 = 8'b00110000;			// 3
				4: HEX2 = 8'b00011001;			// 4
				5: HEX2 = 8'b00010010;			// 5
				6: HEX2 = 8'b00000010;			// 6
				7: HEX2 = 8'b01111000;			// 7
				8: HEX2 = 8'b00000000;			// 8
				9: HEX2 = 8'b00010000;			// 9
				default: HEX2 = 8'b00111111;	// -  
			endcase
			case (H1)
				0: HEX1 = 8'b11000000;			// 0
				1: HEX1 = 8'b11111001;			// 1
				2: HEX1 = 8'b10100100;			// 2
				3: HEX1 = 8'b10110000;			// 3
				4: HEX1 = 8'b10011001;			// 4
				5: HEX1 = 8'b10010010;			// 5
				6: HEX1 = 8'b10000010;			// 6
				7: HEX1 = 8'b11111000;			// 7
				8: HEX1 = 8'b10000000;			// 8
				9: HEX1 = 8'b10010000;			// 9
				default: HEX1 = 8'b10111111;	// -  
			endcase
			case (H0)
				0: HEX0 = 8'b11000000;			// 0
				1: HEX0 = 8'b11111001;			// 1
				2: HEX0 = 8'b10100100;			// 2
				3: HEX0 = 8'b10110000;			// 3
				4: HEX0 = 8'b10011001;			// 4
				5: HEX0 = 8'b10010010;			// 5
				6: HEX0 = 8'b10000010;			// 6
				7: HEX0 = 8'b11111000;			// 7
				8: HEX0 = 8'b10000000;			// 8
				9: HEX0 = 8'b10010000;			// 9
				default: HEX0 = 8'b10111111;	// - 
			endcase
		end

		// Display oven_temp (1)
		// Display preheat temp (3)
		if (display_setting == 1 || display_setting == 3) begin
			if (display_setting == 1) begin
				H1 = oven_temp % 10;
				H2 = ((oven_temp - H1) % 100) / 10;
				H3 = ((oven_temp - H1) - H2 * 10) / 100;
			end
			if (display_setting == 3) begin
				H1 = preheat_temp % 10;
				H2 = ((preheat_temp - H1) % 100) / 10;
				H3 = ((preheat_temp - H1) - H2 * 10) / 100;
			end
			case (H3)
				0: HEX3 = 8'b11000000;			// 0
				1: HEX3 = 8'b11111001;			// 1
				2: HEX3 = 8'b10100100;			// 2
				3: HEX3 = 8'b10110000;			// 3
				4: HEX3 = 8'b10011001;			// 4
				5: HEX3 = 8'b10010010;			// 5
				6: HEX3 = 8'b10000010;			// 6
				7: HEX3 = 8'b11111000;			// 7
				8: HEX3 = 8'b10000000;			// 8
				9: HEX3 = 8'b10010000;			// 9
				default: HEX3 = 8'b10111111;	// - 
			endcase
			case (H2)
				0: HEX2 = 8'b11000000;			// 0
				1: HEX2 = 8'b11111001;			// 1
				2: HEX2 = 8'b10100100;			// 2
				3: HEX2 = 8'b10110000;			// 3
				4: HEX2 = 8'b10011001;			// 4
				5: HEX2 = 8'b10010010;			// 5
				6: HEX2 = 8'b10000010;			// 6
				7: HEX2 = 8'b11111000;			// 7
				8: HEX2 = 8'b10000000;			// 8
				9: HEX2 = 8'b10010000;			// 9
				default: HEX2 = 8'b10111111;	// -  
			endcase
			case (H1)
				0: HEX1 = 8'b11000000;			// 0
				1: HEX1 = 8'b11111001;			// 1
				2: HEX1 = 8'b10100100;			// 2
				3: HEX1 = 8'b10110000;			// 3
				4: HEX1 = 8'b10011001;			// 4
				5: HEX1 = 8'b10010010;			// 5
				6: HEX1 = 8'b10000010;			// 6
				7: HEX1 = 8'b11111000;			// 7
				8: HEX1 = 8'b10000000;			// 8
				9: HEX1 = 8'b10010000;			// 9
				default: HEX1 = 8'b10111111;	// -  
			endcase
			// HEX0 is F for farenhieght 
			HEX0 = 8'b10001110;
		end

		// Set the display state depending on SW8 and SW9
		case (current_display_state)
			SHOW_CLOCK: display_setting = 0;
			SHOW_TEMP: display_setting = 1;
			SET_TIMER: display_setting = 2;
			SET_TEMP: display_setting = 3;
		endcase
	end
	
endmodule