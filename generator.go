package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"math/rand"
	"strconv"
	"time"
)

type Range struct {
	Min float64
	Max float64
}

func (r Range) len() float64 {
	return r.Max - r.Min
}

func (r Range) rand() float64 {
	return r.Min + rand.Float64()*(r.Max-r.Min)
}

type Generator struct {
	ValueRange Range
	TimeRange  Range
}

func parseArg(args map[string][]string, name string) (float64, error) {
	array := args[name]
	if len(array) == 0 {
		return 0, errors.New("no arg")
	}
	return strconv.ParseFloat(array[0], 64)
}

func (g *Generator) FillParameters(args map[string][]string) error {
	var err error
	g.ValueRange.Min, err = parseArg(args, "value_min")
	if err != nil {
		g.ValueRange.Min = 0
	}
	g.ValueRange.Max, err = parseArg(args, "value_max")
	if err != nil {
		g.ValueRange.Max = 1
	}
	if g.ValueRange.len() <= 0 {
		return errors.New("value_max <= value_min")
	}
	g.TimeRange.Min, err = parseArg(args, "interval_min")
	if err != nil {
		g.TimeRange.Min = 0.5
	}
	if g.TimeRange.Min < 0.05 {
		return errors.New("interval_min is too low, needs 50ms or more")
	}
	g.TimeRange.Max, err = parseArg(args, "interval_max")
	if err != nil {
		g.TimeRange.Max = 2
	}
	if g.TimeRange.len() <= 0 {
		return errors.New("interval_max<=interval_min")
	}
	return nil
}

func (g *Generator) NextTimer() *time.Ticker {
	return time.NewTicker(time.Duration(g.TimeRange.rand() * float64(time.Second)))
}

type data struct {
	Data float64 `json:"data"`
}

func (g *Generator) GenerateData() data {
	return data{g.ValueRange.rand()}
}

func (g *Generator) Generate() []byte {
	buffer, _ := json.Marshal(g.GenerateData())
	return buffer
}

func (g *Generator) GenerateSSE(counter int) []byte {
	var buffer bytes.Buffer
	buffer.WriteString("event: random_data\n")
	buffer.WriteString("id: ")
	buffer.WriteString(strconv.Itoa(counter))
	buffer.WriteString("\ndata: ")
	encoder := json.NewEncoder(&buffer)
	encoder.Encode(g.GenerateData())
	buffer.WriteString("\n\n")
	return buffer.Bytes()
}
