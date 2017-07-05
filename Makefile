OUT := $(PWD)/build
BIN := $(OUT)/proxy
SRC := proxy.c
OBJ := $(SRC:%.c=$(OUT)/%.o)


all: $(BIN)

$(OUT):
	mkdir -p $(OUT)

$(OUT)/%.o: %.c $(OUT)
	gcc -c $< -o $@

$(BIN): $(OBJ)
	gcc $^ -o $@

clean:
	rm -rf $(OUT)

install: $(BIN)
	ts /system/xbin/mount -o remount,rw /system
	ts cp $(BIN) /system/xbin/
