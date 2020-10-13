################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
CPP_SRCS += \
../cxxtest/Descriptions.cpp \
../cxxtest/DummyDescriptions.cpp \
../cxxtest/GlobalFixture.cpp \
../cxxtest/LinkedList.cpp \
../cxxtest/RealDescriptions.cpp \
../cxxtest/Root.cpp \
../cxxtest/TestSuite.cpp \
../cxxtest/TestTracker.cpp \
../cxxtest/ValueTraits.cpp 

OBJS += \
./cxxtest/Descriptions.o \
./cxxtest/DummyDescriptions.o \
./cxxtest/GlobalFixture.o \
./cxxtest/LinkedList.o \
./cxxtest/RealDescriptions.o \
./cxxtest/Root.o \
./cxxtest/TestSuite.o \
./cxxtest/TestTracker.o \
./cxxtest/ValueTraits.o 

CPP_DEPS += \
./cxxtest/Descriptions.d \
./cxxtest/DummyDescriptions.d \
./cxxtest/GlobalFixture.d \
./cxxtest/LinkedList.d \
./cxxtest/RealDescriptions.d \
./cxxtest/Root.d \
./cxxtest/TestSuite.d \
./cxxtest/TestTracker.d \
./cxxtest/ValueTraits.d 


# Each subdirectory must supply rules for building sources it contributes
cxxtest/%.o: ../cxxtest/%.cpp
	@echo 'Building file: $<'
	@echo 'Invoking: Cygwin C++ Compiler'
	g++ -O0 -g3 -Wall -c -fmessage-length=0 -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@:%.o=%.d)" -o"$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


