// Automated Speech Recognition Module
// Copyright (C) 2022 SELIDOR - T. Puza, Ł. Wasilewski Sp.J.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
// THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
// WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
// MERCHANTABLITY OR NON-INFRINGEMENT.
// See the Apache 2 License for the specific language governing permissions and
// limitations under the License.

#ifndef HTTPOUTPUTLAYER_H_
#define HTTPOUTPUTLAYER_H_

#include <boost/beast.hpp>
#include <boost/beast/core.hpp>
#include <boost/beast/http.hpp>
#include <boost/beast/version.hpp>
#include <boost/asio/strand.hpp>
#include <boost/asio.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <cstdlib>
#include <functional>
#include <iostream>
#include <memory>
#include <string>
#include <thread>
#include <condition_variable>
#include <mutex>
#include "base/kaldi-error.h"
#include "OutputLayerInterface.h"

using tcp = boost::asio::ip::tcp;       // from <boost/asio/ip/tcp.hpp>
namespace http = boost::beast::http;    // from <boost/beast/http.hpp>

//========== ver 1.75
//namespace beast = boost::beast;         // from <boost/beast.hpp>
//namespace http = beast::http;           // from <boost/beast/http.hpp>
//namespace net = boost::asio;            // from <boost/asio.hpp>
//using tcp = boost::asio::ip::tcp;       // from <boost/asio/ip/tcp.hpp>
//
//class session : public std::enable_shared_from_this<session>
//{
//    tcp::resolver resolver_;
//    beast::tcp_stream stream_;
//    beast::flat_buffer buffer_; // (Must persist between reads)
//    http::request<http::string_body> req_;
//    http::response<http::string_body> res_;
//
//public:
//    // Objects are constructed with a strand to
//    // ensure that handlers do not execute concurrently.
//    explicit
//    session(net::io_context& ioc)
//        : resolver_(net::make_strand(ioc))
//        , stream_(net::make_strand(ioc))
//    {
//    }
//
//    // Start the asynchronous operation
//    void
//    run(
//        char const* host,
//        char const* port,
//        char const* target,
//		std::string data,
//        int version)
//    {
//        // Set up an HTTP GET request message
//        req_.version(version);
//        req_.method(http::verb::post);
//        req_.target(target);
//        req_.set(http::field::host, host);
//        req_.set(http::field::user_agent, BOOST_BEAST_VERSION_STRING);
//        req_.set(field::content_type, "text/plain");
//        req_.body() = data.c_str();
//        req_.prepare_payload();
//
//        // Look up the domain name
//        resolver_.async_resolve(
//            host,
//            port,
//            beast::bind_front_handler(
//                &session::on_resolve,
//                shared_from_this()));
//    }
//
//    void
//    on_resolve(
//        beast::error_code ec,
//        tcp::resolver::results_type results)
//    {
//        if(ec)
//            return fail(ec, "resolve");
//
//        // Set a timeout on the operation
//        stream_.expires_after(std::chrono::seconds(30));
//
//        // Make the connection on the IP address we get from a lookup
//        stream_.async_connect(
//            results,
//            beast::bind_front_handler(
//                &session::on_connect,
//                shared_from_this()));
//    }
//
//    void
//    on_connect(beast::error_code ec, tcp::resolver::results_type::endpoint_type)
//    {
//        if(ec)
//            return fail(ec, "connect");
//
//        // Set a timeout on the operation
//        stream_.expires_after(std::chrono::seconds(30));
//
//        // Send the HTTP request to the remote host
//        http::async_write(stream_, req_,
//            beast::bind_front_handler(
//                &session::on_write,
//                shared_from_this()));
//    }
//
//    void
//    on_write(
//        beast::error_code ec,
//        std::size_t bytes_transferred)
//    {
//        boost::ignore_unused(bytes_transferred);
//
//        if(ec)
//            return fail(ec, "write");
//
//        // Receive the HTTP response
//        http::async_read(stream_, buffer_, res_,
//            beast::bind_front_handler(
//                &session::on_read,
//                shared_from_this()));
//    }
//
//    void
//    on_read(
//        beast::error_code ec,
//        std::size_t bytes_transferred)
//    {
//        boost::ignore_unused(bytes_transferred);
//
//        if(ec)
//            return fail(ec, "read");
//
//        // Write the message to standard out
//        std::cout << res_ << std::endl;
//
//        // Gracefully close the socket
//        stream_.socket().shutdown(tcp::socket::shutdown_both, ec);
//
//        // not_connected happens sometimes so don't bother reporting it.
//        if(ec && ec != beast::errc::not_connected)
//            return fail(ec, "shutdown");
//
//        // If we get here then the connection is closed gracefully
//    }
//};

class HTTPOutputLayer: public OutputLayerInterface {
public:
	HTTPOutputLayer(const std::string& ip, unsigned short port);
	virtual ~HTTPOutputLayer();
	virtual void send(const std::string& data) override;
	virtual const std::string& getResponse() const override;
	virtual const std::string& getSentData() const override;
private:
	void execute();

	// Performs an HTTP GET and prints the response
	class session : public std::enable_shared_from_this<session>
	{
		tcp::resolver resolver_;
		tcp::socket socket_;
		boost::beast::flat_buffer buffer_; // (Must persist between reads)
		http::request<http::string_body> req_;
		http::response<http::string_body> res_;

	public:
		// Resolver and socket require an io_context
		explicit
		session(boost::asio::io_context& ioc)
		: resolver_(ioc)
		, socket_(ioc)
		{
		}

		// Start the asynchronous operation
		void
		run(
				char const* host,
				char const* port,
				char const* target,
				std::string data,
				int version)
		{
			// Set up an HTTP POST request message
			req_.version(version);
			req_.method(http::verb::post);
			req_.target(target);
			req_.set(http::field::host, host);
			req_.set(http::field::user_agent, BOOST_BEAST_VERSION_STRING);
			req_.set(http::field::content_type, "text/plain");
			req_.body() = data.c_str();
			req_.prepare_payload();

			// Look up the domain name
			resolver_.async_resolve(
					host,
					port,
					std::bind(
							&session::on_resolve,
							shared_from_this(),
							std::placeholders::_1,
							std::placeholders::_2));
		}

		void
		on_resolve(
				boost::system::error_code ec,
				tcp::resolver::results_type results)
		{
			if(ec)
				return fail(ec, "resolve");

			// Make the connection on the IP address we get from a lookup
			boost::asio::async_connect(
					socket_,
					results.begin(),
					results.end(),
					std::bind(
							&session::on_connect,
							shared_from_this(),
							std::placeholders::_1));
		}

		void
		on_connect(boost::system::error_code ec)
		{
			if(ec)
				return fail(ec, "connect");

			// Send the HTTP request to the remote host
			http::async_write(socket_, req_,
					std::bind(
							&session::on_write,
							shared_from_this(),
							std::placeholders::_1,
							std::placeholders::_2));
		}

		void
		on_write(
				boost::system::error_code ec,
				std::size_t bytes_transferred)
		{
			boost::ignore_unused(bytes_transferred);

			if(ec)
				return fail(ec, "write");

			// Receive the HTTP response
			http::async_read(socket_, buffer_, res_,
					std::bind(
							&session::on_read,
							shared_from_this(),
							std::placeholders::_1,
							std::placeholders::_2));
		}

		void
		on_read(
				boost::system::error_code ec,
				std::size_t bytes_transferred)
		{
			boost::ignore_unused(bytes_transferred);

			if(ec)
				return fail(ec, "read");

			// Write the message to standard out
			std::cout << res_ << std::endl;

			// Gracefully close the socket
			socket_.shutdown(tcp::socket::shutdown_both, ec);

			// not_connected happens sometimes so don't bother reporting it.
			if(ec && ec != boost::system::errc::not_connected)
				return fail(ec, "shutdown");

			// If we get here then the connection is closed gracefully
		}

		// Report a failure
		void
		fail(boost::system::error_code ec, char const* what)
		{
			KALDI_WARN << what << ": " << ec.message();
		};
	};

	const std::string ip;
	const unsigned short port;

	boost::asio::io_context ioc;
	std::thread thread;
	std::condition_variable lock_thread;
	std::mutex mutex;
	bool continue_thread{true};

	std::string last_response;
	std::string last_data;
};

#endif /* HTTPOUTPUTLAYER_H_ */
