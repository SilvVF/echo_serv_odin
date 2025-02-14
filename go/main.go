package main

import (
	"bufio"
	"context"
	"flag"
	"fmt"
	"net"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"time"
)

var addr = flag.String("addr", "localhost", "server listen address")
var port = flag.Int("port", 9002, "server listen port")

func main() {
	flag.Parse()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	interrupt := make(chan os.Signal, 1)
	signal.Notify(interrupt, os.Interrupt)

	var ip net.IP

	if *addr == "localhost" {
		ip = net.IPv4(127, 0, 0, 1)
	} else {
		split := strings.Split(*addr, ".")
		arr := make([]byte, 4)
		for i, v := range split {
			n, _ := strconv.Atoi(v)
			arr[i] = byte(n)
		}

		ip = net.IPv4(arr[0], arr[1], arr[2], arr[3])
	}

	listener, err := net.ListenTCP("tcp", &net.TCPAddr{
		IP:   ip,
		Port: *port,
	})
	if err != nil {
		panic(err)
	}
	fmt.Println("Listening on", listener.Addr().String())
	defer listener.Close()

	go func() {
		<-interrupt
		fmt.Println("Shutting down...")
		cancel()
		timeout, tCancel := context.WithTimeout(context.Background(), time.Second*3)
		defer tCancel()

		<-timeout.Done()
		listener.Close()
		fmt.Println("Shut down")
	}()

	for {
		fmt.Println("waiting for clients")
		conn, err := listener.AcceptTCP()
		fmt.Println("Accepted client", conn.LocalAddr())

		if err != nil {
			fmt.Println(err)
			break
		}

		go RunListen(conn, ctx)
	}
}

func RunListen(conn *net.TCPConn, ctx context.Context) {
	defer conn.Close()

	scanner := bufio.NewScanner(conn)

outer:
	for scanner.Scan() {

		select {
		case <-ctx.Done():
			fmt.Println("canceled conn")
			break outer
		default:
		}

		b := scanner.Bytes()

		fmt.Println("received:", string(b))
	}
}

func RunEcho(conn *net.TCPConn, ctx context.Context) {

	defer conn.Close()

	conn.SetNoDelay(true)
	conn.SetKeepAlive(true)

	scanner := bufio.NewScanner(conn)

outer:
	for scanner.Scan() {

		select {
		case <-ctx.Done():
			fmt.Println("canceled conn")
			break outer
		default:
		}

		b := scanner.Bytes()

		fmt.Println("received:", string(b))

		conn.Write([]byte("\r\n"))
		conn.Write(b)
		conn.Write([]byte("\r\n"))
	}
}
