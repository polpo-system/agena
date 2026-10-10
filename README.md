# agena

agena is a Gemini server for [polpo](https://github.com/polpo-system/polpo), written in Oberon on
polpo's own TLS 1.3. It serves the files below a directory, a capsule, to `gemini://` clients:

```
loksh agena.Serve capsule cert.pem key.pem
```

serves the directory `capsule` on port 1965. A directory gives its `index.gmi`, or a list of its
files when it has none; a directory named without a slash at the end is redirected to the name
with it. Names starting with a dot, and `..` in a path, are not served. The type of a file comes
from its extension (`.gmi` is `text/gemini`). Each request is logged: the client, the status and
the URL.

```
agena.Serve dir cert.pem key.pem [port] [/host name] [/n count] [/queue n] [/timeout s]
agena.SetQueueLen n
agena.SetTimeout s
agena.Help
```

`/host name` answers only requests for that host (53 for others), `/n count` ends after count
connections. agena serves one client at a time; clients that arrive meanwhile wait in the queue
of the listening socket (16), and each client has ten seconds. `/queue` and `/timeout` change
that for one run; `agena.SetQueueLen` and `agena.SetTimeout` for the next `agena.Serve` of the same
loksh (its shell, or the desktop), since a module stays loaded. Ctrl+C stops the server and closes
its socket. Programs can call `agena.Start(dir, cert, key, host, port, count, queue, secs)`.

## The certificate

The certificate must have an ECDSA P-256 key (the PEM forms `EC PRIVATE KEY` and `PRIVATE KEY`
are read). Gemini clients usually trust a self-signed certificate on first use; openssl makes one:

```
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
  -keyout key.pem -out cert.pem -days 3650 -subj /CN=example.org
```

(The certificate in `test/` is for the tests only: its key is public.)

## Installing

With portia: `loksh portia.Install agena` (and `portia.Install /t agena` runs the tests). By hand, in
the polpo directory:

```
bin/x86/loksh compiler.Compile /s ../agena/agena.Mod
```

(acompiler, a7compiler, rvcompiler or mcompiler for the other ports).

## Tests

`test/AgenaTest.Mod` starts agena in a child process on the files of `test/` and asks for four
pages as a client: `AgenaTest.Run`, in a directory with the files of `test/`.
