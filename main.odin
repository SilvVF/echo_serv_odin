package main

import "core:fmt"
import "core:net"
import "core:slice"

main :: proc() {

	fmt.println("hererer")

	sock, lisetnErr := net.listen_tcp({net.IP4_Loopback, 8080})
	if lisetnErr != nil {
		panic("couldnt listen on to tcp")
	}

	client, source, err := net.accept_tcp(sock)
	if err != nil {
		fmt.printfln("Couldnt accept tcp %v, %v %e", client, source, err)
	}
	fmt.printfln("Accepted tcp %v, %v", client, source)
	buf := make_slice([]byte, 1024)
	fmt.printfln("len buf: %d", len(buf))

	arr := make([]byte, len("escape character esc"))
	i := 0
	for c in "escape character esc" {
		arr[i] = u8(c)
		i += 1
	}
	net.send_tcp(client, arr)
	net.send_tcp(client, []byte{'\r', '\n'})

	c := 0
	for {

		read, err1 := net.recv_tcp(client, buf[c:])
		c += read

		if read == 0 || err1 != nil {
			continue
		}

		fmt.printfln("%d", c)
		fmt.println(string(buf[:c]))

		if buf[c - 1] == '\e' {
			net.close(client)
			break
		}

		if c < 2 {
			continue
		}

		if string(buf[c - 2:c]) == "\r\n" {
			fmt.printf("read %s", string(buf[:c]))
			net.send_tcp(client, []byte{'\r', '\n'})
			net.send_tcp(client, buf[:c])
			slice.fill(buf, 0)
			c = 0
		}
	}
}
