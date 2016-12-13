package main

import (
	"bufio"
	"bytes"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	err := filepath.Walk(".", visit)
	if err != nil {
		log.Fatal(err)
	}
}

func visit(path string, info os.FileInfo, err error) error {
	if info.IsDir() {
		if strings.HasPrefix(path, "Externals") {
			return filepath.SkipDir
		}

		return nil
	}

	if !(strings.HasSuffix(path, ".swift") || strings.HasSuffix(path, ".h")) {
		return nil
	}

	fileBytes, fileReadErr := ioutil.ReadFile(path)
	if fileReadErr != nil {
		return fileReadErr
	}

	fileReader := bytes.NewBuffer(fileBytes)

	fileScanner := bufio.NewScanner(fileReader)

	trimmedLines := []string{}
	for fileScanner.Scan() {
		line := fileScanner.Text()
		trimmedLine := strings.TrimRight(line, " \t\n")
		trimmedLines = append(trimmedLines, trimmedLine)
	}

	if fileScanner.Err() != nil {
		return fileScanner.Err()
	}

	tempFilePath := fmt.Sprintf("%s-tmp", path)
	trimmedTempFile, trimmedFileErr := os.Create(tempFilePath)
	if trimmedFileErr != nil {
		return trimmedFileErr
	}

	for _, trimmedLine := range trimmedLines {
		trimmedLineWithNewline := fmt.Sprintf("%s\n", trimmedLine)
		_, writeErr := trimmedTempFile.WriteString(trimmedLineWithNewline)
		if writeErr != nil {
			return writeErr
		}
	}

	swapContentErr := os.Rename(tempFilePath, path)
	if swapContentErr != nil {
		return swapContentErr
	}

	return nil
}
