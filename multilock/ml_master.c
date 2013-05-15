#include "multilock.h"

/* command line syntax */

char options[] = "ekdqfsp:h?x:";
char usage[] =
    "Usage: ml_master [-p port] [-s] [-f] [-q] [-x script] [-d]\n"
    "\n"
    "  -p port   - specify the port to listen to children on\n"
    "  -s        - specify strict mode (children are not polled without EXPECT)\n"
    "  -f        - specify errors are fatal mode\n"
    "  -q        - speficy quiet mode\n"
    "  -d        - speficy dup errors mode (errors are sent to stdout and stderr)\n"
    "  -x script - specify script to run\n"
    "  -k        - syntax check only\n"
    "  -e        - non-fatal errors, full accounting of errors to stderr, everything to stdout\n";

int                  port, listensock;
struct sockaddr_in   addr;
int                  maxfd;
response_t         * expected_responses;
fd_set               sockets;
int                  num_errors;
int                  terminate;
int                  err_accounting;
sigset_t             full_signal_set;
sigset_t             original_signal_set;

void open_socket()
{
  int rc;

  rc = socket(AF_INET, SOCK_STREAM, 0);
  if(rc == -1)
    fatal("socket failed with ERRNO %d \"%s\"\n", errno, strerror(errno));

  listensock = rc;

  addr.sin_family        = AF_INET;
  addr.sin_port          = htons(port);
  addr.sin_addr.s_addr   = INADDR_ANY;

  rc = bind(listensock, (struct sockaddr *) &addr, sizeof(addr));

  if(rc == -1)
    fatal("bind failed with ERRNO %d \"%s\"\n", errno, strerror(errno));

  FD_ZERO(&sockets);
  FD_SET(listensock, &sockets);
  maxfd = listensock;

  rc = listen(listensock, 10);

  if(rc == -1)
    fatal("listen failed with ERRNO %d \"%s\"\n", errno, strerror(errno));
}

void do_accept()
{
  child_t   * child = malloc(sizeof(*child));
  socklen_t   len;
  int         rc;

  if(child == NULL)
    fatal("Accept malloc failed\n");

  memset(child, 0, sizeof(*child));

  len = sizeof(child->c_addr);

  child->c_socket = accept(listensock, &child->c_addr, &len);

  if(child->c_socket == -1)
    fatal("Accept failed ERRNO %d \"%s\"\n", errno, strerror(errno));

  FD_SET(child->c_socket, &sockets);

  sprintf(child->c_name, "<UNKNOWN_%d>", child->c_socket);

  if(child->c_socket > maxfd)
    maxfd = child->c_socket;

  if(!quiet)
    fprintf(output, "Accept for socket %d\n", child->c_socket);

  child->c_input = fdopen(child->c_socket, "r");

  if(child->c_input == NULL)
    fatal("Accept fdopen for input failed ERRNO %d \"%s\"\n", errno, strerror(errno));

  rc = setvbuf(child->c_input, NULL, _IONBF, 0);

  if(rc != 0)
    fatal("Accept setvbuf for input failed ERRNO %d \"%s\"\n", errno, strerror(errno));

  child->c_output = fdopen(child->c_socket, "w");

  if(child->c_output == NULL)
    fatal("Accept fdopen for output failed ERRNO %d \"%s\"\n", errno, strerror(errno));

  rc = setvbuf(child->c_output, NULL, _IONBF, 0);

  if(rc != 0)
    fatal("Accept setvbuf for output failed ERRNO %d \"%s\"\n", errno, strerror(errno));

  child->c_refcount++;

  child->c_next = children;

  if(children != NULL)
    children->c_prev = child;

  children = child;
}

void close_child(child_t * child)
{
  close(child->c_socket);

  if(!quiet)
    fprintf(output, "Closed child socket %d\n", child->c_socket);

  FD_CLR(child->c_socket, &sockets);

  child->c_socket = 0;
  child->c_refcount--;
}

child_t * find_child_by_fd(int socket)
{
  child_t * child = children;

  while(child != NULL && child->c_socket != socket)
    child = child->c_next;

  return child;
}

child_t * find_child_by_name(const char * name)
{
  child_t * child = children;

  while(child != NULL &&
        strcasecmp(child->c_name, name) != 0)
    child = child->c_next;

  return child;
}

int receive(int watchin, long int timeout_secs)
{
  fd_set          readfds, writefds, exceptfds;
  struct timespec timeout;
  int             rc, i;
  int             timeend = 0;

  if(timeout_secs > 0)
    timeend = time(NULL) + timeout_secs;

  while(1)
    {
      if(timeout_secs > 0)
        {
          timeout.tv_nsec = 0;
          timeout.tv_sec  = timeend - time(NULL);
          if(timeout.tv_sec == 0)
            return -2;
        }
      else if(timeout_secs == 0)
        {
          timeout.tv_nsec = 0;
          timeout.tv_sec  = 0;
        }

      memcpy(&readfds, &sockets, sizeof(sockets));
      if(watchin)
        FD_SET(0, &readfds);

      memcpy(&writefds, &sockets, sizeof(sockets));

      memcpy(&exceptfds, &sockets, sizeof(sockets));
      if(watchin)
        FD_SET(0, &exceptfds);

      if(watchin && !script)
        {
          fprintf(output, "> ");
          fflush(output);
        }

      if(!watchin && !quiet)
        {
          fprintf(output, "Waiting for children\n");
          fflush(output);
        }

      if(timeout_secs >= 0)
        {
          fprintf(output, "About to sleep for %d secs\n", (int) timeout.tv_sec);
          rc = pselect(maxfd + 1, &readfds, NULL, &exceptfds, &timeout, &original_signal_set);
        }
      else
        rc = pselect(maxfd + 1, &readfds, NULL, &exceptfds, NULL, &original_signal_set);

      if(rc == -1)
        {
          if(watchin && !script)
            {
              fprintf(output, "\n");
              fflush(output);
            }

          if(errno == EINTR && !terminate)
            {
              if(timeout_secs >= 0)
                return -2;

              fprintf_stderr("select timed out\n");
              return -1;
            }
          else if(errno == EINTR)
            {
              fprintf_stderr("select terminated by signal\n");
              return -3;
            }
          else
            {
              fprintf_stderr("select failed with ERRNO %d \"%s\"\n", errno, strerror(errno));
              return -1;
            }
        }

      for(i = 0; i <= maxfd; i++)
        {
          if(FD_ISSET(i, &readfds))
            {
              if(watchin && !quiet && i != 0)
                {
                  fprintf(output, "\n");
                  fflush(output);
                }

              if(i == listensock)
                do_accept();
              else
                return i;
            }
          if(FD_ISSET(i, &exceptfds))
            {
              fprintf_stderr("select received exception for socket %d\n", i);
            }
        }
    }
}

void error()
{
  int len = strlen(errdetail);

  num_errors++;

  if(errdetail[len-1] == '\n')
    errdetail[len-1] = '\0';

  if(errno == 0)
    fprintf_stderr("%s\n", errdetail);
  else
    fprintf_stderr("ERRNO %d \"%s\" \"%s\" bad token \"%s\"\n",
                   errno, strerror(errno), errdetail, badtoken);
}

response_t * alloc_resp(child_t * child)
{
  response_t * resp = malloc(sizeof(*resp));

  if(resp == NULL)
    fatal("Could not allocate response\n");

  memset(resp, 0, sizeof(*resp));

  resp->r_child = child;

  if(child != NULL)
    child->c_refcount++;

  return resp;
}

response_t * process_child_response(child_t * child)
{
  int          len;
  response_t * child_resp;
  char       * rest;
  char         line[MAXSTR * 2];

  child_resp = alloc_resp(child);

  len = readln(child->c_input, line, MAXSTR * 2);
  if(len >= 0)
    {
      sprintf(child_resp->r_original, "%s %s", child->c_name, line);
      fprintf(output, "%s\n", child_resp->r_original);

      rest = parse_response(line, child_resp);

      if(rest == NULL)
        return child_resp;

      if(child_resp->r_cmd == CMD_HELLO)
        {
          strncpy(child->c_name, child_resp->r_data, child_resp->r_length);
          child->c_name[child_resp->r_length] = '\0';
        }
    }
  else
    {
      fprintf(output, "%s -2 QUIT OK # socket closed\n", child->c_name);
      close_child(child);
      child_resp->r_cmd    = CMD_QUIT;
      child_resp->r_tag    = -2;
      child_resp->r_status = STATUS_OK;
    }

  return child_resp;
}

void master_command();

response_t * receive_response(int watchin, long int timeout_secs)
{
  int       fd;
  child_t * child;

  fd = receive(watchin, timeout_secs);
  if(fd == -2 && timeout_secs >= 0)
    {
      // Expected timeout
      return NULL;
    }
  else if(fd < 0)
    {
      response_t * resp = alloc_resp(NULL);

      if(fd == -3)
        {
          // signal interrupted select
          fprintf_stderr("Receive interrupted - exiting...\n");
          resp->r_tag    = -1;
          resp->r_cmd    = CMD_QUIT;
          resp->r_status = STATUS_CANCELED;
          strcpy(resp->r_original, "-1 QUIT CANCELED");
          errno = 0;
          strcpy(errdetail, "Receive interrupted - exiting...");
        }
      else
        {
          // some other error occurred
          fprintf_stderr("Receive failed ERRNO %d \"%s\"\n", errno, strerror(errno));
          resp->r_cmd   = CMD_QUIT;
          resp->r_errno = errno;
          resp->r_tag   = -1;
          strcpy(resp->r_data, "Receive failed");
          sprintf(resp->r_original, "-1 QUIT ERRNO %d \"%s\" \"Receive failed\"",
                  errno, strerror(errno));
          strcpy(errdetail, "Receive failed");
          strcpy(badtoken, "");
        }
      return resp;
    }
  else if(watchin && fd == 0)
    {
      return NULL;
    }
  else
    {
      child = find_child_by_fd(fd);

      if(child == NULL)
        fatal("Could not find child for socket %d\n", fd);

      return process_child_response(child);
    }
}

typedef enum master_cmd_t
{
  MCMD_QUIT,
  MCMD_STRICT,
  MCMD_CHILD_CMD,
  MCMD_EXPECT,
  MCMD_FATAL,
  MCMD_SLEEP,
  MCMD_OPEN_BRACE,
  MCMD_CLOSE_BRACE,
  MCMD_SIMPLE_OK,
  MCMD_SIMPLE_AVAILABLE,
  MCMD_SIMPLE_GRANTED,
  MCMD_SIMPLE_DENIED,
  MCMD_SIMPLE_DEADLOCK,
  MCMD_CHILDREN,
} master_cmd_t;

token_t master_commands[] =
{
  {"QUIT",      4, MCMD_QUIT},
  {"STRICT",    6, MCMD_STRICT},
  {"EXPECT",    6, MCMD_EXPECT},
  {"FATAL",     5, MCMD_FATAL},
  {"SLEEP",     5, MCMD_SLEEP},
  {"{",         1, MCMD_OPEN_BRACE},
  {"}",         1, MCMD_CLOSE_BRACE},
  {"OK",        2, MCMD_SIMPLE_OK},
  {"AVAILABLE", 9, MCMD_SIMPLE_AVAILABLE},
  {"GRANTED",   7, MCMD_SIMPLE_GRANTED},
  {"DENIED",    6, MCMD_SIMPLE_DENIED},
  {"DEADLOCK",  8, MCMD_SIMPLE_DEADLOCK},
  {"CHILDREN",  8, MCMD_CHILDREN},
  {"", 0, MCMD_CHILD_CMD}
};

void handle_quit();

/*
 * wait_for_expected_responses
 *
 * Wait for a list of expected responses (in expected_responses). If any unexpected
 * response and this is not being called from handle_quit() force fatal error.
 */
void wait_for_expected_responses(const char * label, int count, const char * last, int could_quit)
{
  response_t   * expect_resp;
  response_t   * child_resp;
  int            fatal = FALSE;

  fprintf(output, "Waiting for %d %s...\n", count, label);
  while(expected_responses != NULL && (children != NULL || could_quit))
    {
      child_resp  = receive_response(FALSE, -1);

      if(terminate && could_quit)
        {
          free_response(child_resp, NULL);
          break;
        }

      expect_resp = check_expected_responses(expected_responses, child_resp);

      if(expect_resp != NULL)
        {
          fprintf(output, "Matched %s\n", expect_resp->r_original);
          free_response(expect_resp, &expected_responses);
          free_response(child_resp, NULL);
        }
      else if(child_resp->r_cmd != CMD_QUIT)
        {
          errno = 0;
          if(err_accounting)
            fprintf(stderr, "%s\nResp:      %s\n",
                    last, child_resp->r_original);
          free_response(child_resp, NULL);
          sprintf(errdetail, "Unexpected response");
          error();

          /* If not called from handle_quit() dump list of expected responses and
           * quit if in error_is_fatal or in a script.
           */
          if(could_quit)
            {
              /* Error must be fatal if script since script can't recover */
              if(error_is_fatal || script)
                fatal = TRUE;
              break;
            }
        }
    }

  /* Abandon any remaining responses */
  while(expected_responses != NULL)
    {
      fprintf_stderr("Abandoning %s\n", expected_responses->r_original);
      free_response(expected_responses, &expected_responses);
    }

  if(fatal || terminate)
    handle_quit();
}

void handle_quit()
{
  response_t   * expect_resp;
  child_t      * child;
  int            count = 0;
  char           out[MAXSTR];

  if(children != NULL)
    {
      for(child = children; child != NULL; child = child->c_next)
        {
          if(child->c_socket == 0)
            continue;

          sprintf(out, "%ld QUIT\n", ++global_tag);
          fputs(out, child->c_output);
          fflush(child->c_output);
  
          /* Build an EXPECT for -1 QUIT for this child */
          expect_resp           = alloc_resp(child);
          expect_resp->r_cmd    = CMD_QUIT;
          expect_resp->r_status = STATUS_OK;
          expect_resp->r_tag    = global_tag;
          sprintf(expect_resp->r_original, "EXPECT %s * QUIT OK", child->c_name); 
          add_response(expect_resp, &expected_responses);
          count++;

          /* Build an EXPECT for -2 QUIT for this child */
          expect_resp           = alloc_resp(child);
          expect_resp->r_cmd    = CMD_QUIT;
          expect_resp->r_status = STATUS_OK;
          expect_resp->r_tag    = -2;
          sprintf(expect_resp->r_original, "EXPECT %s -2 QUIT OK", child->c_name); 
          add_response(expect_resp, &expected_responses);
          count++;
        }

      wait_for_expected_responses("children", count, "QUIT", FALSE);
      fprintf(output, "All children exited\n");
    }

  if(num_errors > 0)
    {
      fprintf_stderr("%d errors\n", num_errors);
      fprintf_stderr("FAIL\n");
    }
  else
    {
      fprintf_stderr("SUCCESS\n");
    }

  exit(num_errors > 0);
}

int expect_one_response(response_t * expect_resp, const char * last)
{
  response_t   * child_resp;
  int            result;

  child_resp = receive_response(FALSE, -1);

  if(terminate)
    result = TRUE;
  else
    result = !compare_responses(expect_resp, child_resp);

  if(result)
    {
      if(err_accounting)
        fprintf(stderr, "%s\n%s\nResp:      %s\n",
                last,
                expect_resp->r_original,
                child_resp->r_original);
    }
  else
    fprintf(output, "Matched\n");

  free_response(expect_resp, NULL);
  free_response(child_resp, NULL);

  return result;
}

void master_command()
{
  char         * rest;
  char           line[MAXSTR * 2];
  char           out[MAXSTR * 2];
  char           last[MAXSTR * 2]; // last command sent
  child_t      * child;
  int            len;
  int            cmd;
  response_t   * expect_resp;
  response_t   * child_resp;
  response_t   * child_cmd;
  long int       secs;
  int            t_end, t_now;
  int            inbrace = FALSE;
  int            count = 0;

  last[0] = '\0';

  while(1)
    {
      len = readln(input, line, MAXSTR);
      lno++;

      if(len < 0)
        {
          len = sprintf(line, "QUIT");
          if(!syntax)
            fprintf(output, "QUIT\n");
        }

      rest = SkipWhite(line, REQUIRES_MORE, "Invalid line");

      /* Skip totally blank line and comments */
      if(rest == NULL || *rest == '#')
        continue;

      if(script && !syntax)
        fprintf(output, "Line %4ld: %s\n", lno, line);

      rest = get_token_value(rest, &cmd, master_commands, TRUE, REQUIRES_EITHER, "Invalid master command");

      if(rest != NULL) switch((master_cmd_t) cmd)
        {
          case MCMD_QUIT:
            if(syntax)
              return;
            else
              handle_quit();
            break;

          case MCMD_STRICT:
            rest = get_on_off(rest, &strict);
            break;

          case MCMD_FATAL:
            rest = get_on_off(rest, &error_is_fatal);
            break;

          case MCMD_CHILD_CMD:
            rest = get_child(line, &child, syntax, REQUIRES_MORE);
            if(rest == NULL)
              break;

            if(script)
              sprintf(last, "Line %4ld: %s", lno, line);
            else
              strcpy(last, line);

            child_cmd = alloc_resp(child);

            rest = parse_request(rest, child_cmd, FALSE);

            if(rest != NULL && !syntax)
              send_cmd(child_cmd);

            free_response(child_cmd, NULL);
            break;

          case MCMD_SLEEP:
            rest = get_long(rest, &secs, TRUE, "Invalid sleep time");
            if(rest == NULL)
              break;

            if(syntax)
              break;

            t_now = time(NULL);
            t_end = t_now + secs;
            while(t_now <= t_end && !terminate)
              {
                child_resp = receive_response(FALSE, t_end - t_now);
                t_now      = time(NULL);

                if(child_resp != NULL)
                  {
                    errno = 0;
      
                    if(err_accounting)
                      fprintf(stderr, "%s\n%s\n", last, child_resp->r_original);
      
                    sprintf(errdetail, "Unexpected response");
                    rest = NULL;
      
                    free_response(child_resp, NULL);
                  }
                /* If sleep 0 or we have run out, just want single iteration */
                if(t_now == t_end)
                  break;
              }
            break;

          case MCMD_OPEN_BRACE:
            if(inbrace)
              {
                errno = 0;
                strcpy(errdetail, "Illegal nested brace");
                rest = NULL;
              }
            count   = 0;
            inbrace = TRUE;
            break;

          case MCMD_CLOSE_BRACE:
            if(!inbrace)
              {
                errno = 0;
                strcpy(errdetail, "Unmatched close brace");
                rest = NULL;
              }
            else if(!syntax)
              {
                inbrace = FALSE;
                wait_for_expected_responses("responses", count, last, TRUE);
                fprintf(output, "All responses received OK\n");
                count = 0;
              }
            else
              {
                inbrace = FALSE;
              }
            break;

          case MCMD_CHILDREN:
            if(inbrace)
              {
                errno = 0;
                strcpy(errdetail, "CHILDREN command not allowed inside brace");
                rest = NULL;
                break;
              }


            while(rest != NULL && *rest != '\0' && *rest != '#')
              {
                /* Get the next child to expect */
                rest = get_child(rest, &child, TRUE, REQUIRES_EITHER);
                if(rest == NULL)
                  break;

                /* Build an EXPECT child * HELLO OK "child" */
                expect_resp = alloc_resp(child);
                expect_resp->r_cmd = CMD_HELLO;
                expect_resp->r_tag = -1;
                expect_resp->r_status = STATUS_OK;
                strcpy(expect_resp->r_data, child->c_name);
                sprintf(expect_resp->r_original, "EXPECT %s * HELLO OK \"%s\"",
                        child->c_name, child->c_name);

                count++;

                if(syntax)
                  {
                    free_response(expect_resp, NULL);
                  }
                else
                  {
                    /* Add response to list of expected responses */
                    add_response(expect_resp, &expected_responses);
                  }
              }

            if(count == 0)
              {
                errno = 0;
                strcpy(errdetail, "Expected at least one child");
                rest = NULL;
                break;
              }

            if(!syntax)
              {
                wait_for_expected_responses("children", count, last, TRUE);
                fprintf(output, "All children said HELLO OK\n");
              }

            count = 0;
            break;

          case MCMD_EXPECT:
            rest = get_child(rest, &child, TRUE, REQUIRES_MORE);

            if(rest == NULL)
              break;

            expect_resp = alloc_resp(child);

            if(script)
              sprintf(expect_resp->r_original, "Line %4ld: EXPECT %s %s",
                      lno, child->c_name, rest);
            else
              sprintf(expect_resp->r_original, "EXPECT %s %s",
                      child->c_name, rest);

            rest = parse_response(rest, expect_resp);

            if(rest == NULL || syntax)
              {
                free_response(expect_resp, NULL);
               }
            else if(inbrace)
              {
                add_response(expect_resp, &expected_responses);
                count++;
              }
            else if(expect_one_response(expect_resp, last))
              {
                rest = NULL;
              }
            break;

          case MCMD_SIMPLE_OK:
          case MCMD_SIMPLE_AVAILABLE:
          case MCMD_SIMPLE_GRANTED:
          case MCMD_SIMPLE_DENIED:
          case MCMD_SIMPLE_DEADLOCK:
            strcpy(last, line);
            rest = get_child(rest, &child, syntax, REQUIRES_MORE);
            if(rest == NULL)
              break;

            child_cmd = alloc_resp(child);

            if(cmd == MCMD_SIMPLE_OK)
              child_cmd->r_status = STATUS_OK;
            else if(cmd == MCMD_SIMPLE_AVAILABLE)
              child_cmd->r_status = STATUS_AVAILABLE;
            else if(cmd == MCMD_SIMPLE_GRANTED)
              child_cmd->r_status = STATUS_GRANTED;
            else if(cmd == MCMD_SIMPLE_DEADLOCK)
              child_cmd->r_status = STATUS_DEADLOCK;
            else
              child_cmd->r_status = STATUS_DENIED;

            rest = parse_request(rest, child_cmd, TRUE);
            if(rest == NULL)
              {
                free_response(child_cmd, NULL);
                break;
              }

            switch(child_cmd->r_cmd)
              {
                case CMD_OPEN:
                case CMD_CLOSE:
                case CMD_SEEK:
                case CMD_WRITE:
                case CMD_COMMENT:
                case CMD_ALARM:
                case CMD_HELLO:
                case CMD_QUIT:
                  if(cmd != MCMD_SIMPLE_OK)
                    {
                      sprintf(errdetail, "Simple %s command expects OK",
                              commands[child_cmd->r_cmd].cmd_name);
                      errno = 0;
                      rest = NULL;
                    }
                  break;

                case CMD_READ:
                  if(cmd != MCMD_SIMPLE_OK)
                    {
                      sprintf(errdetail, "Simple %s command expects OK",
                              commands[child_cmd->r_cmd].cmd_name);
                      errno = 0;
                      rest = NULL;
                    }
                  else if(child_cmd->r_length == 0 || child_cmd->r_data[0] == '\0')
                    {
                      strcpy(errdetail, "Simple READ must have compare data");
                      errno = 0;
                      rest = NULL;
                    }
                  break;

                case CMD_LOCKW:
                  if(cmd != MCMD_SIMPLE_DEADLOCK)
                    {
                      sprintf(errdetail, "%s command can not be a simple command",
                              commands[child_cmd->r_cmd].cmd_name);
                      errno = 0;
                      rest = NULL;
                    }
                  break;

                case CMD_LOCK:
                case CMD_HOP:
                  if(cmd != MCMD_SIMPLE_DENIED &&
                     cmd != MCMD_SIMPLE_GRANTED)
                    {
                      sprintf(errdetail, "Simple %s command requires GRANTED or DENIED status",
                              commands[child_cmd->r_cmd].cmd_name);
                      errno = 0;
                      rest = NULL;
                    }
                  break;

                case CMD_TEST:
                case CMD_LIST:
                  if(cmd != MCMD_SIMPLE_AVAILABLE)
                    {
                      sprintf(errdetail, "Simple %s command requires AVAILABLE status",
                              commands[child_cmd->r_cmd].cmd_name);
                      errno = 0;
                      rest = NULL;
                    }
                  break;

                case CMD_UNLOCK:
                case CMD_UNHOP:
                  if(cmd != MCMD_SIMPLE_GRANTED)
                    {
                      sprintf(errdetail, "Simple %s command requires GRANTED status",
                              commands[child_cmd->r_cmd].cmd_name);
                      errno = 0;
                      rest = NULL;
                    }
                  break;
                  
                case NUM_COMMANDS:
                  strcpy(errdetail, "Invalid command");
                  errno = 0;
                  rest = NULL;
                  break;
              }

            if(rest == NULL || syntax)
              {
                free_response(child_cmd, NULL);
                break;
              }

            send_cmd(child_cmd);
            /* We can't know what file descriptor will be returned */
            child_cmd->r_fno = -1;
            sprintf_resp(out, "EXPECT", child_cmd);
            fprintf(output, "%s", out);

            if(expect_one_response(child_cmd, last))
              rest = NULL;
            break;

        }

      if(rest == NULL)
        {
          error();

          if(syntax)
            fprintf(output, "Line %4ld: %s\n", lno, line);

          if((error_is_fatal && !syntax) || terminate)
            handle_quit();
        }

      if(!strict && !inbrace && !script)
        break;

      if(!script)
        {
          fprintf(output, "> ");
          fflush(output);
        }
    }
}

void sighandler(int sig)
{
  switch(sig)
    {
      case SIGINT:
      case SIGTERM:
      case SIGUSR1:
        terminate = TRUE;
        break;

      case SIGPIPE:
        terminate = TRUE;
        break;
    }
}

int main(int argc, char **argv)
{
  char               c;
  response_t       * resp;
  struct sigaction   sigact;
  int                syntax_only = FALSE;
  int                rc;

  input  = stdin;
  output = stdout;

  memset(&sigact, 0, sizeof(sigact));
  sigact.sa_handler = sighandler;

  rc = sigaction(SIGINT, &sigact, NULL);
  if(rc == -1)
    fatal("sigaction(SIGINT, &sigact, NULL) returned -1 errno %d \"%s\"\n",
          errno, strerror(errno));

  rc = sigaction(SIGTERM, &sigact, NULL);
  if(rc == -1)
    fatal("sigaction(SIGTERM, &sigact, NULL) returned -1 errno %d \"%s\"\n",
          errno, strerror(errno));

  rc = sigaction(SIGUSR1, &sigact, NULL);
  if(rc == -1)
    fatal("sigaction(SIGUSR1, &sigact, NULL) returned -1 errno %d \"%s\"\n",
          errno, strerror(errno));

  rc = sigaction(SIGPIPE, &sigact, NULL);
  if(rc == -1)
    fatal("sigaction(SIGPIPE, &sigact, NULL) returned -1 errno %d \"%s\"\n",
          errno, strerror(errno));

  rc = sigfillset(&full_signal_set);
  if(rc == -1)
    fatal("sigfillset(&full_signal_set) returned -1 errno %d \"%s\"\n",
          errno, strerror(errno));

  sigprocmask(SIG_SETMASK, &full_signal_set, &original_signal_set);

  /* now parsing options with getopt */
  while((c = getopt(argc, argv, options)) != EOF)
    {
      switch (c)
        {
        case 'e':
          duperrors = TRUE;
          err_accounting = TRUE;
          break;

        case 'd':
          duperrors = TRUE;
          break;

        case 'p':
          port = atoi(optarg);
          break;

        case 'q':
          quiet = TRUE;
          break;

        case 's':
          strict = TRUE;
          break;

        case 'x':
          input = fopen(optarg, "r");
          if(input == NULL)
            fatal("Could not open %s\n", optarg);
          script = TRUE;
          break;

        case 'k':
          syntax_only = TRUE;
          break;

        case 'f':
          error_is_fatal = TRUE;
          break;

        case '?':
        case 'h':
        default:
          /* display the help */
          fprintf(stderr, usage);
          fflush(stderr);
          exit(0);
          break;
        }
    }

  open_socket();

  if(script)
    {
      syntax = TRUE;

      master_command();

      if(num_errors != 0)
        {
          fprintf(stdout, "Syntax checks fail\n");
          return 1;
        }

      if(syntax_only)
        {
          fprintf(stdout, "Syntax checks ok\n");
          return 0;
        }

      syntax = FALSE;
      global_tag = lno;
      lno = 0;
      rewind(input);


      master_command();
      // Never returns
    }

  while(1)
    {
      resp = receive_response(TRUE, -1);

      if(strict && resp != NULL)
        {
          errno = 0;
          sprintf(errdetail, "Unexpected response");
          free_response(resp, NULL);
          error();
          if(error_is_fatal)
            handle_quit();
        }

      free_response(resp, NULL);
      master_command();
    }

  // Never get here
  return 0;
}
