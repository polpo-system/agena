MODULE AgenaTest;  (* AgenaTest.Run: agena serves this directory in a child process (cert.pem and key.pem
  for localhost, index.gmi), this process asks for pages as a Gemini client and prints the status
  lines: "20 text/gemini; charset=utf-8", "51 not found" (twice), "53 proxy request refused" *)

IMPORT SYSTEM, Linux0, Kernel, Sockets, TLS13Live, agena, out;

CONST Requests = 4;

VAR s: POINTER TO TLS13Live.State;

PROCEDURE Sleep(ms: LONGINT);  (* GetTimer counts milliseconds on every port (TimeUnit) *)
VAR t: LONGINT;
BEGIN t := Kernel.GetTimer(); WHILE Kernel.GetTimer() - t < ms DO END
END Sleep;

(* waits until port takes connections (the probe is one connection of the server) *)
PROCEDURE Ready(port: LONGINT): BOOLEAN;
VAR a: Sockets.Address; c: Sockets.Socket; i: LONGINT;
BEGIN
  IF ~Sockets.ParseAddress("127.0.0.1", a) THEN RETURN FALSE END;
  i := 0; c := NIL;
  WHILE (c = NIL) & (i < 100) DO c := Sockets.Connect(a, port); IF c = NIL THEN Sleep(100) END; INC(i) END;
  IF c = NIL THEN RETURN FALSE END;
  Sockets.Close(c); RETURN TRUE
END Ready;

PROCEDURE IntToStr(x: LONGINT; VAR a: ARRAY OF CHAR);
VAR d: ARRAY 12 OF CHAR; i, j: LONGINT;
BEGIN
  i := 0; REPEAT d[i] := CHR(x MOD 10 + ORD("0")); x := x DIV 10; INC(i) UNTIL x = 0;
  j := 0; WHILE i > 0 DO DEC(i); a[j] := d[i]; INC(j) END; a[j] := 0X
END IntToStr;

PROCEDURE Append(VAR a: ARRAY OF CHAR; b: ARRAY OF CHAR);
VAR i, j: LONGINT;
BEGIN
  i := 0; WHILE a[i] # 0X DO INC(i) END;
  j := 0; WHILE (b[j] # 0X) & (i < LEN(a) - 1) DO a[i] := b[j]; INC(i); INC(j) END;
  a[i] := 0X
END Append;

(* the request url, the status line printed; body: the answer contains it *)
PROCEDURE Get(url, port, body: ARRAY OF CHAR);
VAR req: ARRAY 256 OF CHAR; buf: ARRAY 4096 OF CHAR; n, got, i, j: LONGINT; found: BOOLEAN;
BEGIN
  IF ~TLS13Live.ConnectPinned("localhost", port, s^, "") THEN out.String("no connection: "); out.String(TLS13Live.lastError); out.Ln; RETURN END;
  COPY(url, req); i := 0; WHILE req[i] # 0X DO INC(i) END; req[i] := 0DX; req[i + 1] := 0AX; req[i + 2] := 0X;
  IF ~TLS13Live.WriteAppString(s^, req) THEN out.String("not sent"); out.Ln END;
  n := 0;
  WHILE (n < LEN(buf) - 1) & TLS13Live.ReadAppMax(s^, req, 255, got) DO
    i := 0; WHILE (i < got) & (n < LEN(buf) - 1) DO buf[n] := req[i]; INC(n); INC(i) END
  END;
  buf[n] := 0X; TLS13Live.Disconnect(s^);
  i := 0; WHILE (buf[i] # 0X) & (buf[i] # 0DX) DO INC(i) END;
  out.String("status: "); j := 0; WHILE j < i DO out.Char(buf[j]); INC(j) END; out.Ln;
  IF body[0] # 0X THEN
    found := FALSE; i := 0;
    WHILE ~found & (buf[i] # 0X) DO
      j := 0; WHILE (body[j] # 0X) & (buf[i + j] = body[j]) DO INC(j) END;
      found := body[j] = 0X; INC(i)
    END;
    IF found THEN out.String("body: ") ELSE out.String("body missing: ") END;
    out.String(body); out.Ln
  END
END Get;

PROCEDURE Run*;
VAR pid, port, r, st: LONGINT; p: ARRAY 8 OF CHAR; url: ARRAY 64 OF CHAR;
BEGIN
  IF s = NIL THEN NEW(s) END;
  port := 20000 + Kernel.GetTimer() MOD 20000; IntToStr(port, p);
  pid := Linux0.Fork0();
  IF pid = 0 THEN agena.Start(".", "cert.pem", "key.pem", "localhost", port, Requests + 1, 4, 5); Linux0.Exit0(0) END;
  IF ~Ready(port) THEN out.String("the server did not start"); out.Ln
  ELSE
    url := "gemini://localhost:"; r := 0; WHILE url[r] # 0X DO INC(r) END; st := 0;
    WHILE p[st] # 0X DO url[r] := p[st]; INC(r); INC(st) END; url[r] := 0X;
    r := 0; WHILE url[r] # 0X DO INC(r) END;
    url[r] := "/"; url[r + 1] := 0X; Get(url, p, "zq test capsule");
    url[r] := 0X; Append(url, "/nothing.gmi"); Get(url, p, "");
    url[r] := 0X; Append(url, "/x/../index.gmi"); Get(url, p, "");
    Get("https://localhost/", p, "")
  END;
  st := 0; r := Linux0.Waitpid0(pid, SYSTEM.ADR(st), 0);
  IF (r = pid) & (st = 0) THEN out.String("the server ended") ELSE out.String("the server failed") END;
  out.Ln
END Run;

END AgenaTest.
