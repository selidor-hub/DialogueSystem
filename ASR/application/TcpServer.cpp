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

#include "TcpServer.h"

namespace kaldi {

TcpServer::TcpServer(int read_timeout) {
  server_desc_ = -1;
  client_desc_ = -1;
  samp_buf_ = NULL;
  buf_len_ = 0;
  read_timeout_ = 1000 * read_timeout;
}

bool TcpServer::Listen(int32 port) {
  h_addr_.sin_addr.s_addr = INADDR_ANY;
  h_addr_.sin_port = htons(port);
  h_addr_.sin_family = AF_INET;

  server_desc_ = socket(AF_INET, SOCK_STREAM, 0);

  if (server_desc_ == -1) {
    KALDI_ERR << "Cannot create TCP socket!";
    return false;
  }

  int32 flag = 1;
  int32 len = sizeof(int32);
  if (setsockopt(server_desc_, SOL_SOCKET, SO_REUSEADDR, &flag, len) == -1) {
    KALDI_ERR << "Cannot set socket options!";
    return false;
  }

  if (bind(server_desc_, (struct sockaddr *) &h_addr_, sizeof(h_addr_)) == -1) {
    KALDI_ERR << "Cannot bind to port: " << port << " (is it taken?)";
    return false;
  }

  if (listen(server_desc_, 1) == -1) {
    KALDI_ERR << "Cannot listen on port!";
    return false;
  }

  KALDI_LOG << "TcpServer: Listening on port: " << port;

  return true;

}

TcpServer::~TcpServer() {
  Disconnect();
  if (server_desc_ != -1)
    close(server_desc_);
  delete[] samp_buf_;
}

int32 TcpServer::Accept() {
  KALDI_LOG << "Waiting for client...";

  socklen_t len;

  len = sizeof(struct sockaddr);
  client_desc_ = accept(server_desc_, (struct sockaddr *) &h_addr_, &len);

  struct sockaddr_storage addr;
  char ipstr[20];

  len = sizeof addr;
  getpeername(client_desc_, (struct sockaddr *) &addr, &len);

  struct sockaddr_in *s = (struct sockaddr_in *) &addr;
  inet_ntop(AF_INET, &s->sin_addr, ipstr, sizeof ipstr);

  client_set_[0].fd = client_desc_;
  client_set_[0].events = POLLIN;

  KALDI_LOG << "Accepted connection from: " << ipstr;

  return client_desc_;
}

bool TcpServer::ReadChunk(size_t len) {
  if (buf_len_ != len) {
    buf_len_ = len;
    delete[] samp_buf_;
    samp_buf_ = new int16[len];
  }

  ssize_t ret;
  int poll_ret;
  char *samp_buf_p = reinterpret_cast<char *>(samp_buf_);
  size_t to_read = len * sizeof(int16);
  has_read_ = 0;
  while (to_read > 0) {
    poll_ret = poll(client_set_, 1, read_timeout_);
    if (poll_ret == 0) {
      KALDI_WARN << "Socket timeout! Disconnecting..." << "(has_read_ = " << has_read_ << ")";
      break;
    }
    if (poll_ret < 0) {
      KALDI_WARN << "Socket error! Disconnecting...";
      break;
    }
    ret = read(client_desc_, static_cast<void *>(samp_buf_p + has_read_), to_read);
    if (ret <= 0) {
      KALDI_WARN << "Stream over...";
      break;
    }
    to_read -= ret;
    has_read_ += ret;
  }
  has_read_ /= sizeof(int16);

  return has_read_ > 0;
}

Vector<BaseFloat> TcpServer::GetChunk() {
  Vector<BaseFloat> buf;

  buf.Resize(static_cast<MatrixIndexT>(has_read_));

  for (int i = 0; i < has_read_; i++)
    buf(i) = static_cast<BaseFloat>(samp_buf_[i]);

  return buf;
}

bool TcpServer::Write(const std::string &msg) {

  const char *p = msg.c_str();
  size_t to_write = msg.size();
  size_t wrote = 0;
  while (to_write > 0) {
    ssize_t ret = write(client_desc_, static_cast<const void *>(p + wrote), to_write);
    if (ret <= 0)
      return false;

    to_write -= ret;
    wrote += ret;
  }

  return true;
}

bool TcpServer::WriteLn(const std::string &msg, const std::string &eol) {
  if (Write(msg))
    return Write(eol);
  else return false;
}

void TcpServer::Disconnect() {
  if (client_desc_ != -1) {
    close(client_desc_);
    client_desc_ = -1;
  }
}

}  // namespace kaldi

