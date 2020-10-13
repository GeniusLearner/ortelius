################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
CPP_SRCS += \
../sample/yes_no_runner.cpp 

OBJS += \
./sample/yes_no_runner.o 

CPP_DEPS += \
./sample/yes_no_runner.d 


# Each subdirectory must supply rules for building sources it contributes
sample/%.o: ../sample/%.cpp
	@echo 'Building file: $<'
	@echo 'Invoking: Cygwin C++ Compiler'
	g++ -O0 -g3 -Wall -c -fmessage-length=0 -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@:%.o=%.d)" -o"$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


