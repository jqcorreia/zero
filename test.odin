package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:testing"

TEST_FOLDER :: "tests"

@(test)
run_tests :: proc(_: ^testing.T) {
	handle, _ := os.open(TEST_FOLDER)
	fis, _ := os.read_dir(handle, -1)
	for fi in fis {
		fmt.println(fi)
	}

	assert(false)
	// for k, v in os.read_dir("tests") {

	// 	fmt.println(k, v)
	// }
}
