package main

import (
	"testing"
	"time"
)

func TestBurnCheckoutCPUIsBounded(t *testing.T) {
	started := time.Now()
	burnCheckoutCPU(time.Millisecond)
	if elapsed := time.Since(started); elapsed < time.Millisecond || elapsed > time.Second {
		t.Fatalf("burnCheckoutCPU ran for %s", elapsed)
	}
}
