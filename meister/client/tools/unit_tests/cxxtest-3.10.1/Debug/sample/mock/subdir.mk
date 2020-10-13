################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
CPP_SRCS += \
../sample/mock/Dice.cpp \
../sample/mock/mock_stdlib.cpp \
../sample/mock/real_stdlib.cpp \
../sample/mock/roll.cpp 

OBJS += \
./sample/mock/Dice.o \
./sample/mock/mock_stdlib.o \
./sample/mock/real_stdlib.o \
./sample/mock/roll.o 

CPP_DEPS += \
./sample/mock/Dice.d \
./sample/mock/mock_stdlib.d \
./sample/mock/real_stdlib.d \
./sample/mock/roll.d 


# Each subdirectory must supply rules for building sources it contributes
sample/mock/%.o: ../sample/mock/%.cpp
	@echo 'Building file: $<'
	@echo 'Invoking: Cygwin C++ Compiler'
	g++ -O0 -g3 -Wall -c -fmessage-length=0 -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@:%.o=%.d)" -o"$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


