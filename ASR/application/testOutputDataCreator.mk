CPPFLAGS=-std=c++11 
GTEST=/usr/local/lib/libgtest.a
LIBS=-lpthread

TARGET=testOutputDataCreator

testOutputDataCreator: $(TARGET).o OutputDataCreator.o
	g++ $(CPPFLAGS) -o $(TARGET) testOutputDataCreator.o OutputDataCreator.o $(GTEST) $(LIBS)
	
clean:
	$(RM) $(TARGET) OutputDataCreator.o testOutputDataCreator.o