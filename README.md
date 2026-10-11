# agena

agena is a Gemini server for [polpo](https://github.com/polpo-system/polpo), written in Oberon on
polpo's own TLS 1.3. It serves the files below a directory, a capsule, to `gemini://` clients:

```
loksh agena.Serve capsule cert.pem key.pem
```

serves the directory `capsule` on port 1965. A directory gives its `index.gmi`, or a list of its
files when it has none; a directory named without a slash at the end is redirected to the name
with it. Names starting with a dot, and `..` in a path, are not served. The type of a file comes
from its extension (`.gmi` is `text/gemini`, see Types). Each request is logged: the client, the
status and the URL. Several capsules under different names on one port: see Virtual hosts.

```
agena.Serve dir cert.pem key.pem [port] [/host name] [/n count] [/queue n] [/timeout s]
agena.Serve /config agena.toml [port] [/n count] [/queue n] [/timeout s]
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

## Virtual hosts: several servers on one port

One agena can serve several capsules, each under its own name, with its own directory and
certificate, on the same port. They are described in a configuration file, in TOML:

```
loksh agena.Serve /config agena.toml
```

```toml
# agena.toml
port    = 1965     # optional, these three
queue   = 16       # connections waiting while one is served
timeout = 10       # seconds a client may take

[[server]]
name  = "սոնա.հայ"
root  = "/srv/gemini/սոնա.հայ/pub"
cert  = "/srv/gemini/սոնա.հայ/fullchain.pem"
key   = "/srv/gemini/սոնա.հայ/privkey.pem"
index = "index.gmi"   # optional, the default

[[server]]
name  = "norayr.am"
root  = "/srv/gemini/norayr.am/pub"
cert  = "/srv/gemini/norayr.am/norayr.am.crt"
key   = "/srv/gemini/norayr.am/norayr.am.key"

[types]
mp3 = "audio/mpeg"
ogg = "audio/ogg"
```

Each `[[server]]` needs `name`, `root`, `cert` and `key`; `index` is the file a directory gives
(`index.gmi` if it is not there). `agena.toml.example` in this repository is a copy to start
from. Options given on the command line (the port, `/queue`, `/timeout`) win over those of the
file, so `agena.Serve /config agena.toml 1966` tries the same servers on another port.

How a server is chosen:

- The client names the host it wants in the TLS handshake (SNI), before anything else is sent.
  That name chooses the server, and agena answers with its certificate. A name that is not in
  the file is refused with the alert unrecognized_name.
- A client that names no host (it connects by address) gets the server of the host in its URL;
  agena then answers the handshake with the certificate of the first server.
- The host in the URL of the request must be the name of the chosen server; a request for
  another host is answered 53 (proxy request refused).

Names may be written in UTF-8, as `սոնա.հայ`. Clients send such names in punycode
(`xn--y9a5bft.xn--y9a3aq`), and agena converts the names of the file in the same way before it
compares them; capitals are lowered (ASCII and Armenian letters). A URL may carry the host in
either form. Each server is announced at the start (`agena: serving ... as xn--...`), so the
punycode of a name can be seen there.

Programs can call `agena.StartConfig(file, port, count, queue, secs)`.

## Types

The answer to a file starts with its type (`20 text/gemini; charset=utf-8`), taken from the
extension of its name, without regard to case:

| extension | type |
| --- | --- |
| `.gmi`, `.gemini` | `text/gemini; charset=utf-8` |
| `.txt`, `.mod` | `text/plain; charset=utf-8` |
| `.md` | `text/markdown; charset=utf-8` |
| `.html`, `.htm` | `text/html; charset=utf-8` |
| `.xml`, `.atom` | `application/xml` |
| `.png` | `image/png` |
| `.jpg`, `.jpeg` | `image/jpeg` |
| `.gif` | `image/gif` |
| `.svg` | `image/svg+xml` |
| `.pdf` | `application/pdf` |
| `.gz` | `application/gzip` |
| `.zip` | `application/zip` |
| anything else | `application/octet-stream` |

The table `[types]` of the configuration file adds types, or changes these: each line is an
extension, without its dot, and its type. Its entries are looked at first, so

```toml
[types]
mp3 = "audio/mpeg"
ogg = "audio/ogg"
txt = "text/plain; charset=koi8-r"
```

serves `.mp3` and `.ogg` files with their types, and `.txt` files with another character set.
The types apply to all the servers of the file. (A directory without its index file is listed as
`text/gemini`.)

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

`test/AgenaTest.Mod` starts agena in a child process on the files of `test/` and asks for pages
as a client, in a directory with the files of `test/`: `AgenaTest.Run` (one directory),
`AgenaTest.Hosts` (the two servers of `test/agena.toml`) and `AgenaTest.Names` (punycode).
