#include <memory>
#include <thread>
#include <atomic>
#include <functional>
#include <cstdint>
#include <cstring>

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#else
#include <unistd.h>
#include <arpa/inet.h>
#endif
#ifdef __APPLE__
#include <netinet/in.h>
#include <netinet/in_systm.h>
#include <netinet/ip.h>
#include <netinet/ip_icmp.h>
#endif

#include "ping.h"

using namespace std::chrono_literals;

#pragma pack(push)
#pragma pack(1)

struct echo_req_t
{
  struct
  {
    uint8_t type;
    uint8_t code;
    uint16_t checksum;
    uint16_t id;
    uint16_t sequence;
  } hdr;
  char msg[32];
};

struct echo_res_t
{
#if defined(__APPLE__) || defined(_WIN32)
  char ip_hdr[20];
#endif
  struct
  {
    uint8_t type;
    uint8_t code;
    uint16_t checksum;
    uint16_t id;
    uint16_t sequence;
  } hdr;
  char msg[32];
};

#pragma pack(pop)

static uint16_t ping_package_checksum(echo_req_t &pkg);

static std::unique_ptr<std::thread> ping_thread;
static std::atomic<bool> ping_stop_signal = false;

void ping_start(
    std::function<void(ping_time_point, ping_duration)> on_echo_reply,
    std::function<void(std::string)> on_error)
{
#ifdef _WIN32
  WSADATA wsock;
  if (WSAStartup(MAKEWORD(2, 2), &wsock) != 0)
  {
    on_error("could not initialize windows sockets");
    return;
  }
#endif

  ping_thread = std::make_unique<std::thread>([on_echo_reply, on_error]() {
  // create datagram socket
#ifdef _WIN32
    auto sock = socket(AF_INET, SOCK_RAW, IPPROTO_ICMP);
#else
    auto sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
#endif
    if (sock < 0)
    {
      on_error("could not open raw/datagram socket");
      return;
    }

// set receive timeout
#ifdef _WIN32
    DWORD rcv_timeout = 5000;
#else
    timeval rcv_timeout{};
    rcv_timeout.tv_sec = 5;
    rcv_timeout.tv_usec = 0;
#endif
    if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char *)&rcv_timeout, sizeof(rcv_timeout)) != 0)
    {
      on_error("could not set receive timeout");
#ifdef _WIN32
      closesocket(sock);
#else
      close(sock);
#endif
      return;
    }

    // our ping target address: 8.8.8.8
    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    if (inet_pton(AF_INET, "8.8.8.8", &addr.sin_addr) != 1)
    {
      on_error("could not parse ip address");
#ifdef _WIN32
      closesocket(sock);
#else
      close(sock);
#endif
      return;
    }

    // prepare echo package
    echo_req_t pkg_send{};
    pkg_send.hdr.type = 8;
#ifdef _WIN32
    pkg_send.hdr.id = GetCurrentProcessId();
#else
    pkg_send.hdr.id = htons(getpid());
#endif
    for (size_t i = 0; i < sizeof(pkg_send.msg) - 1; i++)
    {
      pkg_send.msg[i] = i + '0';
    }

    // ping loop
    for (uint16_t seq = 0; !ping_stop_signal; ++seq)
    {
      // finalize echo package
      pkg_send.hdr.sequence = htons(seq);
      pkg_send.hdr.checksum = 0;
      pkg_send.hdr.checksum = ping_package_checksum(pkg_send);

      // send echo package
      ping_time_point tp1 = std::chrono::system_clock::now();

      if (sendto(sock, (const char *)&pkg_send, sizeof(pkg_send), 0, (struct sockaddr *)&addr, sizeof(addr)) <= 0)
      {
        on_error("could not send echo package");
        std::this_thread::sleep_for(3s);
        continue;
      }

      // receive echo reply package
      echo_res_t pkg_rcv{};
      sockaddr_in rcv_addr{};
      socklen_t rcv_addr_len = sizeof(rcv_addr);
      if (recvfrom(sock, (char *)&pkg_rcv, sizeof(pkg_rcv), 0, (struct sockaddr *)&rcv_addr, &rcv_addr_len) <= 0)
      {
        on_error("could not receive echo reply package");
        std::this_thread::sleep_for(3s);
        continue;
      }

      // evaluate reply package
      if (pkg_rcv.hdr.type == 0 && pkg_rcv.hdr.code == 0 && std::memcmp(pkg_rcv.msg, pkg_send.msg, sizeof(pkg_rcv.msg)) == 0)
      {
        // NOTE: Comparing ids does not work on Linux. The kernel places its own id
        //       in the outgoing package and therefore we cannot match it here with our id.
        //       It works on macOS though. Not sure about Windows. Well, this is just
        //       a simple demo...
        //
        // NOTE: We should actually check the sequence number here and
        //       continue to receive the next package in case the received
        //       sequence number is smaller than the last sent sequence number.
        //       Well, this is just a simple demo...

        ping_time_point tp2 = std::chrono::system_clock::now();
        ping_duration dur = tp2 - tp1;

        if (dur.count() >= 0)
        {
          on_echo_reply(tp1, dur);
        }
        else
        {
          on_error("clock jump detected, skipping package");
        }
        std::this_thread::sleep_for(1s);
      }
      else
      {
        on_error("invalid echo reply package received");
        std::this_thread::sleep_for(3s);
      }
    }

    // close socket properly
#ifdef _WIN32
    closesocket(sock);
#else
    close(sock);
#endif
  });
}

void ping_stop()
{
  ping_stop_signal = true;

  if (ping_thread)
  {
    ping_thread->join();
    ping_thread.reset();
  }
}

static uint16_t ping_package_checksum(echo_req_t &pkg)
{
  size_t len = sizeof(echo_req_t);
  uint16_t *buf = (uint16_t *)&pkg;
  uint32_t sum = 0;
  uint16_t result;
  for (sum = 0; len >= 2; len -= 2)
    sum += *buf++;
  if (len == 1)
    sum += *(uint8_t *)buf;
  sum = (sum >> 16) + (sum & 0xFFFF);
  sum += (sum >> 16);
  result = ~sum;
  return result;
}
