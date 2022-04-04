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

#ifndef HTTPSOUTPUTLAYER_H_
#define HTTPSOUTPUTLAYER_H_


#include <boost/beast.hpp>
#include <boost/beast/core.hpp>
#include <boost/beast/http.hpp>
#include <boost/beast/version.hpp>
#include <boost/asio/strand.hpp>
#include <boost/asio.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <boost/asio/ssl/error.hpp>
#include <boost/asio/ssl/stream.hpp>
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
#include <sstream>

using tcp = boost::asio::ip::tcp;       // from <boost/asio/ip/tcp.hpp>
namespace http = boost::beast::http;    // from <boost/beast/http.hpp>
namespace ssl = boost::asio::ssl;

class HTTPSOutputLayer: public OutputLayerInterface {
public:
	HTTPSOutputLayer(const std::string& ip, const std::string& port, const std::string& path);
	virtual ~HTTPSOutputLayer();
	virtual void send(const std::string& data) override;
	virtual const std::string& getResponse() const override;
	virtual const std::string& getSentData() const override;
private:
	void execute();

	// Performs an HTTP POST
	class session : public std::enable_shared_from_this<session>
	{
		tcp::resolver resolver_;
		// tcp::socket socket_;
		ssl::stream<tcp::socket> stream_;
		boost::beast::flat_buffer buffer_; // (Must persist between reads)
		http::request<http::string_body> req_;
		http::response<http::string_body> res_;
		std::function<void(const std::string&)> response_callback;

	public:
		// Resolver and socket require an io_context
		explicit
		session(boost::asio::io_context& ioc, ssl::context& ctx, std::function<void(const std::string&)> response_callback)
		: resolver_(ioc)
		, stream_(ioc, ctx),
		response_callback(response_callback)
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
			// Set SNI Hostname (many hosts need this to handshake successfully)
			if(! SSL_set_tlsext_host_name(stream_.native_handle(), host))
			{
				boost::system::error_code ec{static_cast<int>(::ERR_get_error()), boost::asio::error::get_ssl_category()};
				std::cerr << ec.message() << "\n";
				return;
			}

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
					stream_.next_layer(),
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

			// Perform the SSL handshake
			stream_.async_handshake(
					ssl::stream_base::client,
					std::bind(
							&session::on_handshake,
							shared_from_this(),
							std::placeholders::_1));
		}

		void
		on_handshake(boost::system::error_code ec)
		{
			if(ec)
				return fail(ec, "handshake");

			KALDI_VLOG(1) << "Request: " << req_;
			// Send the HTTP request to the remote host
			http::async_write(stream_, req_,
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
			http::async_read(stream_, buffer_, res_,
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

			// Handle the message
			response_callback(res_.body());
			KALDI_VLOG(1) << res_;

			// Gracefully close the stream
			stream_.async_shutdown(
					std::bind(
							&session::on_shutdown,
							shared_from_this(),
							std::placeholders::_1));
		}

		void
		on_shutdown(boost::system::error_code ec)
		{
			if(ec == boost::asio::error::eof)
			{
				// Rationale:
				// http://stackoverflow.com/questions/25587403/boost-asio-ssl-async-shutdown-always-finishes-with-an-error
				ec.assign(0, ec.category());
			}
			if(ec)
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
	const std::string port;
	const std::string path;

	boost::asio::io_context ioc;
	ssl::context ctx;
	std::thread thread;
	std::condition_variable lock_thread;
	std::mutex mutex;
	bool continue_thread{true};

	std::string last_response;
	std::string last_data;
};

#endif /* HTTPSOUTPUTLAYER_H_ */
