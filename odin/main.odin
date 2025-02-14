package main

import "core:fmt"
import "core:net"
import "core:strings"
import "core:thread"

is_ctrl_d :: proc(bytes: []u8) -> bool {
	return len(bytes) == 1 && bytes[0] == 4
}

is_empty :: proc(bytes: []u8) -> bool {
	return(
		(len(bytes) == 2 && bytes[0] == '\r' && bytes[1] == '\n') ||
		(len(bytes) == 1 && bytes[0] == '\n') \
	)
}

is_telnet_ctrl_c :: proc(bytes: []u8) -> bool {
	return(
		(len(bytes) == 3 && bytes[0] == 255 && bytes[1] == 251 && bytes[2] == 6) ||
		(len(bytes) == 5 &&
				bytes[0] == 255 &&
				bytes[1] == 244 &&
				bytes[2] == 255 &&
				bytes[3] == 253 &&
				bytes[4] == 6) \
	)
}


main :: proc() {
	endpoint := net.Endpoint {
		address = net.IP4_Loopback,
		port    = 8080,
	}
	sock, err := net.listen_tcp({net.IP4_Loopback, 8080})
	if err != nil {
		fmt.println("Failed to listen on TCP")
		return
	}

	defer net.close(sock)

	fmt.println(strings.concatenate({"Listening on TCP: ", net.endpoint_to_string(endpoint)}))
	for {

		conn, _, err_accept := net.accept_tcp(sock)

		if err_accept != nil {
			fmt.println("Failed to accept TCP connection")
		}

		thread.create_and_start_with_poly_data(conn, proc(data: net.TCP_Socket) {

			defer net.close(data)


			buf := [1024]u8{}
			offset := 0

			for {

				bytes := net.recv_tcp(data, buf[offset:]) or_break

				if bytes <= 0 {
					continue
				}

				offset += bytes
				recv := buf[offset - bytes:offset]

				fmt.printfln("Server received [ %d bytes ]: %s", len(recv), recv)

				if is_ctrl_d(recv) || is_telnet_ctrl_c(recv) {
					fmt.println("Disconnecting client")
					break
				}

				if !is_empty(recv) {
					continue
				}

				new_buf := make([]u8, offset + 2)
				copy(new_buf[0:], "\r\n")
				copy(new_buf[2:], buf[:offset])
				sent, err_send := net.send_tcp(data, new_buf)

				if err_send != nil {
					fmt.println("Failed to send data")
				}
				sent_msg := buf[:sent]

				fmt.printfln("Server sent [ %d bytes ]: %s", len(sent_msg), sent_msg)


				offset = 0
			}
		})
	}
}
