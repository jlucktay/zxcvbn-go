package main

import (
	"bufio"
	"fmt"
	"os"

	"go.jlucktay.dev/zxcvbn-go"
)

func main() {
	for {
		fmt.Println("Enter password or Ctrl-c to exit:")
		reader := bufio.NewReader(os.Stdin)
		password, err := reader.ReadString('\n')
		if err != nil {
			fmt.Fprintf(os.Stderr, "error reading: %v", err)

			continue
		}
		// password := "Testaaatyhg890l33t"

		passwordStenght := zxcvbn.PasswordStrength(password, nil)

		fmt.Printf("Password score    (0-4): %d\nEstimated entropy (bit): %f\nEstimated time to crack: %s\n\n",
			passwordStenght.Score,
			passwordStenght.Entropy,
			passwordStenght.CrackTimeDisplay,
		)
	}
}
