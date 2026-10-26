#!/system/bin/sh

mixer="tinymix"
# Enable Path
ENABLE=1
# Analog PGA Gain: 40: => 20dB, step 0.5dB
A_PGA_L="40"
A_PGA_R="40"
# SPK volume
D_DAC_GAIN="126"
D_DRIVER_GAIN="1"
# Input Differential Gain 0db
INPUT_GAIN_SEL=0
# ADC Mute
MUTE=0
# FPGA Header Reporting
FPGA_HEADER=0

tlv320adc3101_setup() {
	# Setup TI ADCs path
	${mixer} "ADC_A Left Ip Select ADC_A DIF1_L switch" ${ENABLE}
	${mixer} "ADC_A Right Ip Select ADC_A DIF1_R switch" ${ENABLE}
	${mixer} "ADC_B Left Ip Select ADC_B DIF1_L switch" ${ENABLE}
	${mixer} "ADC_B Right Ip Select ADC_B DIF1_R switch" ${ENABLE}
	${mixer} "ADC_C Left Ip Select ADC_C DIF1_L switch" ${ENABLE}
	${mixer} "ADC_C Right Ip Select ADC_C DIF1_R switch" ${ENABLE}
	${mixer} "ADC_D Left Ip Select ADC_D DIF1_L switch" ${ENABLE}
	${mixer} "ADC_D Right Ip Select ADC_D DIF1_R switch" ${ENABLE}

	# Analog PGA Gain
	${mixer} "ADC_A MICPGA Volume Ctrl" ${A_PGA_L} ${A_PGA_R}
	${mixer} "ADC_B MICPGA Volume Ctrl" ${A_PGA_L} ${A_PGA_R}
	${mixer} "ADC_C MICPGA Volume Ctrl" ${A_PGA_L} ${A_PGA_R}
	${mixer} "ADC_D MICPGA Volume Ctrl" ${A_PGA_L} ${A_PGA_R}

	# PGA Input Selection
	${mixer} "ADC_A DIF1_L Input Gain" ${INPUT_GAIN_SEL}
	${mixer} "ADC_A DIF1_R Input Gain" ${INPUT_GAIN_SEL}
	${mixer} "ADC_B DIF1_L Input Gain" ${INPUT_GAIN_SEL}
	${mixer} "ADC_B DIF1_R Input Gain" ${INPUT_GAIN_SEL}
	${mixer} "ADC_C DIF1_L Input Gain" ${INPUT_GAIN_SEL}
	${mixer} "ADC_C DIF1_R Input Gain" ${INPUT_GAIN_SEL}
	${mixer} "ADC_D DIF1_L Input Gain" ${INPUT_GAIN_SEL}
	${mixer} "ADC_D DIF1_R Input Gain" ${INPUT_GAIN_SEL}

	# Unmute
	${mixer} "ADC_A Left Mute" ${MUTE}
	${mixer} "ADC_A Right Mute" ${MUTE}
	${mixer} "ADC_B Left Mute" ${MUTE}
	${mixer} "ADC_B Right Mute"  ${MUTE}
	${mixer} "ADC_C Left Mute" ${MUTE}
	${mixer} "ADC_C Right Mute" ${MUTE}
	${mixer} "ADC_D Left Mute" ${MUTE}
	${mixer} "ADC_D Right Mute" ${MUTE}

	# Pass mic audio to upper layer without FPGA header
	${mixer} 'SpiTimeStamps'  ${FPGA_HEADER}
}

tlv32dac3203_setup()  {
	# Enable Playback route
	# Note that it's differential signal
	${mixer} "HPL Output Mixer L_DAC Switch" ${ENABLE}
	${mixer} "HPR Output Mixer L_DAC Switch" ${ENABLE}

	# Gain setting
	${mixer} "PCM Playback Volume" ${D_DAC_GAIN} ${D_DAC_GAIN}
	${mixer} "HP Driver Gain Volume" ${D_DRIVER_GAIN} ${D_DRIVER_GAIN}
}


persistentLed_setup() {
    touch /tmp/persistentLedState
    chmod 0776 /tmp/persistentLedState
}

# Mics Setup
tlv320adc3101_setup
# Speakers Setup
tlv32dac3203_setup
# Set up persistent LED file
persistentLed_setup
