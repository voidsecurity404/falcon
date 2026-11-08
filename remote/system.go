package main

import (
	"bufio"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

const historyLen = 90

// Sampler measures the system once a second, but only while the app has asked for data recently.
type Sampler struct {
	sampleMu sync.Mutex
	mu       sync.Mutex
	wanted   time.Time
	wake     chan struct{}
	snapshot Overview
	procs    []Proc
	prevCPU  []cpuTimes
	prevNet  map[string][2]uint64
	prevDisk [2]uint64
	prevProc map[int]uint64
	prevAt   time.Time
	cpuHist  []float64
	memHist  []float64
	rxHist   []float64
	txHist   []float64
	users    map[uint32]string
}

type cpuTimes struct{ idle, total uint64 }

type Overview struct {
	Host     string               `json:"host"`
	OS       string               `json:"os"`
	Kernel   string               `json:"kernel"`
	CPUModel string               `json:"cpuModel"`
	Uptime   float64              `json:"uptime"`
	Load     []float64            `json:"load"`
	CPU      float64              `json:"cpu"`
	Cores    []float64            `json:"cores"`
	FreqMHz  float64              `json:"freqMHz"`
	GPUMHz   float64              `json:"gpuMHz"`
	Temp     float64              `json:"temp"`
	Mem      MemInfo              `json:"mem"`
	Disks    []Disk               `json:"disks"`
	Net      NetInfo              `json:"net"`
	DiskIO   [2]float64           `json:"diskIO"`
	Battery  *Battery             `json:"battery"`
	Procs    int                  `json:"procs"`
	Running  int                  `json:"running"`
	History  map[string][]float64 `json:"history"`
	Session  bool                 `json:"session"`
	User     string               `json:"user"`
}

type MemInfo struct {
	Total     uint64 `json:"total"`
	Used      uint64 `json:"used"`
	Available uint64 `json:"available"`
	Cached    uint64 `json:"cached"`
	SwapTotal uint64 `json:"swapTotal"`
	SwapUsed  uint64 `json:"swapUsed"`
}

type Disk struct {
	Mount string `json:"mount"`
	FS    string `json:"fs"`
	Total uint64 `json:"total"`
	Used  uint64 `json:"used"`
}

type NetInfo struct {
	Iface   string  `json:"iface"`
	RxRate  float64 `json:"rx"`
	TxRate  float64 `json:"tx"`
	RxTotal uint64  `json:"rxTotal"`
	TxTotal uint64  `json:"txTotal"`
}

type Battery struct {
	Percent int     `json:"percent"`
	Status  string  `json:"status"`
	Watts   float64 `json:"watts"`
}

type Proc struct {
	PID     int     `json:"pid"`
	PPID    int     `json:"ppid"`
	Name    string  `json:"name"`
	Cmd     string  `json:"cmd"`
	User    string  `json:"user"`
	State   string  `json:"state"`
	CPU     float64 `json:"cpu"`
	Mem     uint64  `json:"mem"`
	Threads int     `json:"threads"`
	Age     float64 `json:"age"`
	Mine    bool    `json:"mine"`
}

func NewSampler() *Sampler {
	s := &Sampler{wake: make(chan struct{}, 1), prevNet: map[string][2]uint64{}, prevProc: map[int]uint64{}, users: map[uint32]string{}}
	go s.loop()
	return s
}

// Touch keeps sampling alive and waits for the first sample after a quiet time.
func (s *Sampler) Touch() {
	s.mu.Lock()
	idle := time.Since(s.wanted) > 15*time.Second
	s.wanted = time.Now()
	s.mu.Unlock()
	if idle {
		select {
		case s.wake <- struct{}{}:
		default:
		}
		// Rates need two samples, so the first answer after a quiet time waits for the second.
		s.sample()
		time.Sleep(600 * time.Millisecond)
		s.sample()
	}
}

func (s *Sampler) loop() {
	for {
		s.mu.Lock()
		active := time.Since(s.wanted) < 15*time.Second
		s.mu.Unlock()
		if !active {
			<-s.wake
			continue
		}
		s.sample()
		time.Sleep(time.Second)
	}
}

func (s *Sampler) Get() (Overview, []Proc) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.snapshot, s.procs
}

func readFile(p string) string {
	b, _ := os.ReadFile(p)
	return strings.TrimSpace(string(b))
}

func readNum(p string) float64 {
	v, _ := strconv.ParseFloat(readFile(p), 64)
	return v
}

var clockTick = 100.0

func uptime() float64 {
	f := strings.Fields(readFile("/proc/uptime"))
	if len(f) == 0 {
		return 0
	}
	v, _ := strconv.ParseFloat(f[0], 64)
	return v
}

func bootTime() time.Time { return time.Now().Add(-time.Duration(uptime() * float64(time.Second))) }

var staticOnce sync.Once
var static struct{ host, os, kernel, cpu string }

func (s *Sampler) sample() {
	s.sampleMu.Lock()
	defer s.sampleMu.Unlock()
	staticOnce.Do(func() {
		static.host, _ = os.Hostname()
		static.kernel = readFile("/proc/sys/kernel/osrelease")
		for _, line := range strings.Split(readFile("/etc/os-release"), "\n") {
			if strings.HasPrefix(line, "PRETTY_NAME=") {
				static.os = strings.Trim(strings.TrimPrefix(line, "PRETTY_NAME="), `"`)
			}
		}
		for _, line := range strings.Split(readFile("/proc/cpuinfo"), "\n") {
			if strings.HasPrefix(line, "model name") {
				static.cpu = strings.TrimSpace(strings.SplitN(line, ":", 2)[1])
				break
			}
		}
	})
	now := time.Now()
	s.mu.Lock()
	dt := now.Sub(s.prevAt).Seconds()
	if dt < 0.5 && !s.prevAt.IsZero() {
		// Too soon after the last sample: short deltas give wild percentages.
		s.mu.Unlock()
		return
	}
	first := s.prevAt.IsZero() || dt > 10
	s.prevAt = now
	s.mu.Unlock()

	o := Overview{Host: static.host, OS: static.os, Kernel: static.kernel, CPUModel: static.cpu, Uptime: uptime(), Session: hasSession()}
	if u, err := userName(uint32(os.Getuid()), s); err == nil {
		o.User = u
	}
	for _, f := range strings.Fields(readFile("/proc/loadavg"))[:3] {
		v, _ := strconv.ParseFloat(f, 64)
		o.Load = append(o.Load, v)
	}

	// CPU from /proc/stat: the first line is the total, then one per core.
	var times []cpuTimes
	for _, line := range strings.Split(readFile("/proc/stat"), "\n") {
		if !strings.HasPrefix(line, "cpu") {
			continue
		}
		f := strings.Fields(line)
		var t cpuTimes
		for i, v := range f[1:] {
			n, _ := strconv.ParseUint(v, 10, 64)
			if i < 8 {
				t.total += n
			}
			if i == 3 || i == 4 {
				t.idle += n
			}
		}
		times = append(times, t)
	}
	s.mu.Lock()
	prev := s.prevCPU
	s.prevCPU = times
	s.mu.Unlock()
	usage := func(i int) float64 {
		if i >= len(prev) {
			return 0
		}
		dt := float64(times[i].total - prev[i].total)
		if dt <= 0 {
			return 0
		}
		return 100 * (1 - float64(times[i].idle-prev[i].idle)/dt)
	}
	if len(times) > 0 {
		o.CPU = usage(0)
		for i := 1; i < len(times); i++ {
			o.Cores = append(o.Cores, usage(i))
		}
	}
	freqs, _ := filepath.Glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq")
	for _, f := range freqs {
		o.FreqMHz += readNum(f) / 1000
	}
	if len(freqs) > 0 {
		o.FreqMHz /= float64(len(freqs))
	}
	if g, _ := filepath.Glob("/sys/class/drm/card*/gt_cur_freq_mhz"); len(g) > 0 {
		o.GPUMHz = readNum(g[0])
	}
	o.Temp = cpuTemp()

	// Memory.
	mem := map[string]uint64{}
	for _, line := range strings.Split(readFile("/proc/meminfo"), "\n") {
		f := strings.Fields(line)
		if len(f) >= 2 {
			v, _ := strconv.ParseUint(f[1], 10, 64)
			mem[strings.TrimSuffix(f[0], ":")] = v * 1024
		}
	}
	o.Mem = MemInfo{Total: mem["MemTotal"], Available: mem["MemAvailable"], Cached: mem["Cached"] + mem["Buffers"], SwapTotal: mem["SwapTotal"], SwapUsed: mem["SwapTotal"] - mem["SwapFree"]}
	o.Mem.Used = o.Mem.Total - o.Mem.Available

	o.Disks = disks()

	// Network: the interface that moved the most data.
	var best string
	var bestTotal uint64
	counters := map[string][2]uint64{}
	for _, line := range strings.Split(readFile("/proc/net/dev"), "\n")[2:] {
		parts := strings.SplitN(line, ":", 2)
		if len(parts) != 2 {
			continue
		}
		name := strings.TrimSpace(parts[0])
		f := strings.Fields(parts[1])
		if name == "lo" || len(f) < 9 || strings.HasPrefix(name, "veth") || strings.HasPrefix(name, "docker") {
			continue
		}
		rx, _ := strconv.ParseUint(f[0], 10, 64)
		tx, _ := strconv.ParseUint(f[8], 10, 64)
		counters[name] = [2]uint64{rx, tx}
		if rx+tx > bestTotal {
			best, bestTotal = name, rx+tx
		}
	}
	s.mu.Lock()
	if p, ok := s.prevNet[best]; ok && !first && dt > 0 {
		o.Net = NetInfo{Iface: best, RxRate: float64(counters[best][0]-p[0]) / dt, TxRate: float64(counters[best][1]-p[1]) / dt}
	} else {
		o.Net.Iface = best
	}
	o.Net.RxTotal, o.Net.TxTotal = counters[best][0], counters[best][1]
	s.prevNet = counters
	s.mu.Unlock()

	// Disk reads and writes of whole disks.
	var rd, wr uint64
	for _, line := range strings.Split(readFile("/proc/diskstats"), "\n") {
		f := strings.Fields(line)
		if len(f) < 10 {
			continue
		}
		name := f[2]
		if _, err := os.Stat("/sys/block/" + name); err != nil || strings.HasPrefix(name, "loop") || strings.HasPrefix(name, "zram") {
			continue
		}
		r, _ := strconv.ParseUint(f[5], 10, 64)
		w, _ := strconv.ParseUint(f[9], 10, 64)
		rd += r * 512
		wr += w * 512
	}
	s.mu.Lock()
	if !first && dt > 0 && s.prevDisk[0] > 0 {
		o.DiskIO = [2]float64{float64(rd-s.prevDisk[0]) / dt, float64(wr-s.prevDisk[1]) / dt}
	}
	s.prevDisk = [2]uint64{rd, wr}
	s.mu.Unlock()

	o.Battery = battery()
	procs := s.readProcs(dt, first, o.Mem.Total)
	o.Procs = len(procs)
	for _, p := range procs {
		if p.State == "R" {
			o.Running++
		}
	}

	s.mu.Lock()
	push := func(h []float64, v float64) []float64 {
		h = append(h, v)
		if len(h) > historyLen {
			h = h[len(h)-historyLen:]
		}
		return h
	}
	if !first {
		s.cpuHist = push(s.cpuHist, o.CPU)
		s.rxHist = push(s.rxHist, o.Net.RxRate)
		s.txHist = push(s.txHist, o.Net.TxRate)
	}
	if o.Mem.Total > 0 {
		s.memHist = push(s.memHist, 100*float64(o.Mem.Used)/float64(o.Mem.Total))
	}
	o.History = map[string][]float64{"cpu": s.cpuHist, "mem": s.memHist, "rx": s.rxHist, "tx": s.txHist}
	s.snapshot = o
	s.procs = procs
	s.mu.Unlock()
}

func cpuTemp() float64 {
	dirs, _ := filepath.Glob("/sys/class/hwmon/hwmon*")
	for _, want := range []string{"coretemp", "k10temp", "zenpower", "cpu_thermal", "acpitz"} {
		for _, d := range dirs {
			if readFile(d+"/name") == want {
				if v := readNum(d + "/temp1_input"); v > 0 {
					return v / 1000
				}
			}
		}
	}
	return 0
}

func battery() *Battery {
	bats, _ := filepath.Glob("/sys/class/power_supply/BAT*")
	if len(bats) == 0 {
		return nil
	}
	d := bats[0]
	b := &Battery{Percent: int(readNum(d + "/capacity")), Status: readFile(d + "/status")}
	if p := readNum(d + "/power_now"); p > 0 {
		b.Watts = p / 1e6
	} else if c, v := readNum(d+"/current_now"), readNum(d+"/voltage_now"); c > 0 {
		b.Watts = c * v / 1e12
	}
	return b
}

var realFS = map[string]bool{"ext4": true, "ext3": true, "btrfs": true, "xfs": true, "vfat": true, "exfat": true, "ntfs3": true, "ntfs": true, "f2fs": true, "zfs": true, "bcachefs": true, "fuseblk": true}

func disks() []Disk {
	var out []Disk
	seen := map[string]bool{}
	for _, line := range strings.Split(readFile("/proc/mounts"), "\n") {
		f := strings.Fields(line)
		if len(f) < 3 || !realFS[f[2]] || seen[f[0]] {
			continue
		}
		mount := strings.ReplaceAll(f[1], `\040`, " ")
		var st syscall.Statfs_t
		if syscall.Statfs(mount, &st) != nil || st.Blocks == 0 {
			continue
		}
		seen[f[0]] = true
		total := st.Blocks * uint64(st.Bsize)
		out = append(out, Disk{Mount: mount, FS: f[2], Total: total, Used: total - st.Bfree*uint64(st.Bsize)})
	}
	sort.Slice(out, func(i, j int) bool { return len(out[i].Mount) < len(out[j].Mount) })
	return out
}

func userName(uid uint32, s *Sampler) (string, error) {
	if name, ok := s.users[uid]; ok {
		return name, nil
	}
	f, err := os.Open("/etc/passwd")
	if err != nil {
		return "", err
	}
	defer f.Close()
	scan := bufio.NewScanner(f)
	for scan.Scan() {
		p := strings.Split(scan.Text(), ":")
		if len(p) > 2 {
			id, _ := strconv.ParseUint(p[2], 10, 32)
			s.users[uint32(id)] = p[0]
		}
	}
	name, ok := s.users[uid]
	if !ok {
		name = strconv.Itoa(int(uid))
		s.users[uid] = name
	}
	return name, nil
}

func (s *Sampler) readProcs(dt float64, first bool, memTotal uint64) []Proc {
	entries, _ := os.ReadDir("/proc")
	up := uptime()
	me := uint32(os.Getuid())
	page := uint64(os.Getpagesize())
	next := map[int]uint64{}
	var out []Proc
	for _, e := range entries {
		pid, err := strconv.Atoi(e.Name())
		if err != nil {
			continue
		}
		raw := readFile("/proc/" + e.Name() + "/stat")
		open, close := strings.IndexByte(raw, '('), strings.LastIndexByte(raw, ')')
		if open < 0 || close < 0 {
			continue
		}
		f := strings.Fields(raw[close+2:])
		if len(f) < 22 {
			continue
		}
		var st syscall.Stat_t
		if syscall.Stat("/proc/"+e.Name(), &st) != nil {
			continue
		}
		utime, _ := strconv.ParseUint(f[11], 10, 64)
		stime, _ := strconv.ParseUint(f[12], 10, 64)
		threads, _ := strconv.Atoi(f[17])
		start, _ := strconv.ParseFloat(f[19], 64)
		rss, _ := strconv.ParseUint(f[21], 10, 64)
		ppid, _ := strconv.Atoi(f[1])
		if f[0] == "Z" && rss == 0 && threads == 0 {
			continue
		}
		used := utime + stime
		next[pid] = used
		p := Proc{PID: pid, PPID: ppid, Name: raw[open+1 : close], State: f[0], Mem: rss * page, Threads: threads, Age: up - start/clockTick, Mine: st.Uid == me}
		// Kernel threads have no memory and no command line.
		if rss == 0 && ppid == 2 || pid == 2 {
			continue
		}
		p.User, _ = userName(st.Uid, s)
		if old, ok := s.prevProc[pid]; ok && !first && dt > 0 {
			p.CPU = float64(used-old) / clockTick / dt * 100
		}
		cmd := strings.TrimSpace(strings.ReplaceAll(readFile("/proc/"+e.Name()+"/cmdline"), "\x00", " "))
		if len(cmd) > 300 {
			cmd = cmd[:300]
		}
		p.Cmd = cmd
		out = append(out, p)
	}
	s.prevProc = next
	return out
}
