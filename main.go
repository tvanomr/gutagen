package main

import (
	"flag"
	"log"
	"net/http"
	"strconv"
)

func MirrorCORS(input http.Header, output http.Header) {
	origins, ok := input["Origin"]
	if ok {
		for _, value := range origins {
			output.Add("Access-Control-Allow-Origin", value)
		}
	}
}

func main() {
	pPort := flag.Int("port", 24433, "port to listen on")
	flag.Parse()
	http.HandleFunc("/stream", func(w http.ResponseWriter, r *http.Request) {
		flusher := w.(http.Flusher)
		err := r.ParseForm()
		if err != nil {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		var gen Generator
		err = gen.FillParameters(r.Form)
		if err != nil {
			w.WriteHeader(http.StatusBadRequest)
			w.Write([]byte(err.Error()))
			return
		}
		w.Header().Add("Content-Type", "text/json")
		MirrorCORS(r.Header, w.Header())
		w.WriteHeader(http.StatusOK)
		w.Write(append([]byte("\n"), gen.Generate()...))
		flusher.Flush()
		for {
			ticker := gen.NextTimer()
			select {
			case <-r.Context().Done():
				return
			case <-ticker.C:
				w.Write(append([]byte("\n"), gen.Generate()...))
				flusher.Flush()
			}
		}
	})
	http.HandleFunc("/sse", func(w http.ResponseWriter, r *http.Request) {
		flusher := w.(http.Flusher)
		err := r.ParseForm()
		if err != nil {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		var gen Generator
		err = gen.FillParameters(r.Form)
		if err != nil {
			w.WriteHeader(http.StatusBadRequest)
			w.Write([]byte(err.Error()))
			return
		}
		w.Header().Add("Cache-Control", "no-cache")
		w.Header().Add("Content-Type", "text/event-stream; charset=utf-8")
		MirrorCORS(r.Header, w.Header())
		w.WriteHeader(http.StatusOK)
		w.Write(gen.GenerateSSE(0))
		flusher.Flush()
		counter := 1
		log.Println("started")
		for {
			ticker := gen.NextTimer()
			select {
			case <-r.Context().Done():
				log.Println("stopped")
				return
			case <-ticker.C:
				w.Write(gen.GenerateSSE(counter))
				counter++
				flusher.Flush()
			}
		}
	})
	http.ListenAndServe(":"+strconv.Itoa(*pPort), nil)
}
