package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/bubbles/textarea"
	"github.com/charmbracelet/bubbles/textinput"
	"github.com/charmbracelet/lipgloss"
)

type focus int

const (
	focusSender focus = iota
	focusMessage
	focusSend
)

type sendResultMsg struct {
	err error
}

type model struct {
	sender   textinput.Model
	message  textarea.Model
	focus    focus
	sending  bool
	status   string
	endpoint string
	w, h     int
}

func initialModel() model {
	s := textinput.New()
	s.Placeholder = "Your name"
	s.CharLimit = 64
	s.Prompt = "> "

	t := textarea.New()
	t.Placeholder = "Your message..."
	t.ShowLineNumbers = false
	t.CharLimit = 200

	m := model{
		sender:   s,
		message:  t,
		focus:    focusSender,
		status:   "Ready",
		endpoint: "https://print.erwann.xyz/send_message_web",
	}
	m.setFocus(m.focus)
	return m
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.w, m.h = msg.Width, msg.Height
		m.applyLayout()

	case tea.KeyMsg:
		if msg.String() == "ctrl+c" || msg.String() == "esc" {
			return m, tea.Quit
		}
		if m.sending {
			break
		}

		switch msg.String() {
		case "tab", "shift+tab":
			if msg.String() == "tab" {
				m.focus = (m.focus + 1) % 3
			} else {
				m.focus = (m.focus + 2) % 3
			}
			m.setFocus(m.focus)
			return m, nil

		case "enter":
			if m.focus == focusSend {
				return m, m.trySend()
			}
			if m.focus == focusSender {
				m.focus = focusMessage
				m.setFocus(m.focus)
				return m, nil
			}

		case "ctrl+s":
			return m, m.trySend()
		}

	case sendResultMsg:
		m.sending = false
		if msg.err != nil {
			m.status = "Error: " + msg.err.Error()
		} else {
			m.status = "Sent ✓"
			m.message.SetValue("")
			m.focus = focusMessage
			m.setFocus(m.focus)
		}
		return m, nil
	}

	if m.focus == focusSender {
		m.sender, cmd = m.sender.Update(msg)
		return m, cmd
	}
	if m.focus == focusMessage {
		m.message, cmd = m.message.Update(msg)
		return m, cmd
	}

	return m, nil
}

func (m *model) trySend() tea.Cmd {
	sender := strings.TrimSpace(m.sender.Value())
	text := strings.TrimSpace(m.message.Value())

	if sender == "" {
		m.status = "Sender required"
		m.focus = focusSender
		m.setFocus(m.focus)
		return nil
	}
	if text == "" {
		m.status = "Message required"
		m.focus = focusMessage
		m.setFocus(m.focus)
		return nil
	}

	m.status = "Sending..."
	m.sending = true
	return sendMessageCmd(m.endpoint, sender, text)
}

func (m *model) setFocus(f focus) {
	m.sender.Blur()
	m.message.Blur()

	switch f {
	case focusSender:
		m.sender.Focus()
	case focusMessage:
		m.message.Focus()
	case focusSend:
	}
}

func (m *model) applyLayout() {
	maxW := clamp(48, m.w-6, 90)
	m.sender.Width = maxW - 6
	m.message.SetWidth(maxW - 6)

	msgH := clamp(6, m.h-10, 16)
	m.message.SetHeight(msgH)
}

func (m model) View() string {
	w := clamp(48, m.w-6, 90)

	title := lipgloss.NewStyle().Bold(true).Render("fax-tui")
	hints := lipgloss.NewStyle().Faint(true).Render("tab next • enter send (on button) • ctrl+s send • esc quit")

	box := lipgloss.NewStyle().
		Width(w).
		Border(lipgloss.RoundedBorder()).
		Padding(1, 2)

	label := lipgloss.NewStyle().Bold(true).Render
	faint := lipgloss.NewStyle().Faint(true).Render

	btnBase := lipgloss.NewStyle().
		Padding(0, 2).
		Border(lipgloss.RoundedBorder()).
		Bold(true)

	btn := btnBase
	if m.focus == focusSend {
		btn = btn.Reverse(true)
	}

	btnText := "SEND"
	if m.sending {
		btnText = "SENDING..."
	}

	content := strings.Join([]string{
		title + "  " + hints,
		"",
		label("Sender"),
		m.sender.View(),
		"",
		label("Message"),
		m.message.View(),
		"",
		btn.Render(btnText),
		"",
		faint(fmt.Sprintf("%d chars", len([]rune(m.message.Value())))),
	}, "\n")

	status := lipgloss.NewStyle().Faint(true).Render(m.status)

	return box.Render(content) + "\n" + status + "\n"
}

func sendMessageCmd(endpoint, sender, message string) tea.Cmd {
	return func() tea.Msg {
		type payload struct {
			Message string `json:"message"`
			Sender  string `json:"sender"`
		}

		b, err := json.Marshal(payload{Message: message, Sender: sender})
		if err != nil {
			return sendResultMsg{err: err}
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		req, err := http.NewRequestWithContext(ctx, "POST", endpoint, bytes.NewReader(b))
		if err != nil {
			return sendResultMsg{err: err}
		}
		req.Header.Set("Content-Type", "application/json")

		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			return sendResultMsg{err: err}
		}
		defer resp.Body.Close()

		if resp.StatusCode < 200 || resp.StatusCode >= 300 {
			raw, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
			msg := strings.TrimSpace(string(raw))
			if msg == "" {
				msg = fmt.Sprintf("HTTP %d", resp.StatusCode)
			} else {
				msg = fmt.Sprintf("HTTP %d: %s", resp.StatusCode, msg)
			}
			return sendResultMsg{err: fmt.Errorf(msg)}
		}

		return sendResultMsg{err: nil}
	}
}

func clamp(lo, x, hi int) int {
	if x < lo {
		return lo
	}
	if x > hi {
		return hi
	}
	return x
}

func main() {
	p := tea.NewProgram(initialModel())
	if _, err := p.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
