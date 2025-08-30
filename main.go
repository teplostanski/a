package main

import (
  "fmt"
  "io/fs"
  "os"
  "os/exec"
  "path/filepath"
  "strings"

  tea "github.com/charmbracelet/bubbletea"
  "github.com/charmbracelet/lipgloss"
)

type menuState int

const (
  stateMainMenu menuState = iota
  stateSelectUser
  stateSelectSudoFile
  stateConfirmDelete
  stateConfirmation
)

type actionType int

const (
  actionNone actionType = iota
  actionAdd
  actionRemove
)

type model struct {
  state            menuState
  cursor           int
  options          []string
  users            []string
  sudoFiles        []string
  message          string
  action           actionType
  selectedSudoFile string
  isRoot           bool
}

var (
  styleSelected   = lipgloss.NewStyle().Reverse(true).Bold(true)
  styleDefault    = lipgloss.NewStyle()
  styleHeader     = lipgloss.NewStyle().Foreground(lipgloss.Color("8")).Bold(true)
  styleSubtleText = lipgloss.NewStyle().Foreground(lipgloss.Color("8"))
)

var githubURL = "https://github.com/teplostanski/nosudopass"
var version = "dev" // this rewrite GoReleaser
var app = "nosudopass"

func main() {
  m := model{
    state:   stateMainMenu,
    cursor:  0,
    options: []string{"Allow sudo without password", "Disable sudo without password", "Exit"},
    isRoot:  os.Geteuid() == 0,
  }

  if !m.isRoot {
    fmt.Println("⚠ Running without root privileges. Some functions may not work.")
  }

  if _, err := tea.NewProgram(m).Run(); err != nil {
    fmt.Println("Error:", err)
    os.Exit(1)
  }
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
  switch msg := msg.(type) {
  case tea.KeyMsg:
    switch msg.String() {
    case "ctrl+c", "q":
      return m, tea.Quit
    case "up", "k":
      if m.cursor > 0 {
        m.cursor--
      }
    case "down", "j":
      if m.cursor < len(m.options)-1 {
        m.cursor++
      }
    case "enter":
      switch m.state {
      case stateMainMenu:
        switch m.cursor {
        case 0:
          if !m.isRoot {
            m.message = "❌ Root privileges required to modify sudoers."
            m.state = stateConfirmation
            break
          }
          m.users = getUsers()
          if len(m.users) == 0 {
            m.message = "No users with home directories found."
            m.state = stateConfirmation
            break
          }
          m.options = append([]string{"⬅ Back"}, m.users...)
          m.cursor = 0
          m.state = stateSelectUser
          m.action = actionAdd
        case 1:
          if !m.isRoot {
            m.message = "❌ Root privileges required to remove sudoers files."
            m.state = stateConfirmation
            break
          }
          m.sudoFiles = getSudoFiles()
          if len(m.sudoFiles) == 0 {
            m.message = "No sudoers files to remove."
            m.state = stateConfirmation
            break
          }
          m.options = append([]string{"⬅ Back"}, m.sudoFiles...)
          m.cursor = 0
          m.state = stateSelectSudoFile
          m.action = actionRemove
        case 2:
          return m, tea.Quit
        }
      case stateSelectUser:
        if m.cursor == 0 {
          m.backToMain()
          break
        }
        user := m.users[m.cursor-1]
        err := addSudoNoPass(user)
        if err != nil {
          m.message = fmt.Sprintf("Error: %v", err)
        } else {
          m.message = fmt.Sprintf("User %s can now run sudo without password.", user)
        }
        m.state = stateConfirmation
      case stateSelectSudoFile:
        if m.cursor == 0 {
          m.backToMain()
          break
        }
        m.selectedSudoFile = m.sudoFiles[m.cursor-1]
        m.options = []string{
          fmt.Sprintf("Delete %s", filepath.Base(m.selectedSudoFile)),
          "Cancel",
        }
        m.cursor = 0
        m.state = stateConfirmDelete
      case stateConfirmDelete:
        if m.cursor == 0 {
          err := os.Remove(m.selectedSudoFile)
          if err != nil {
            m.message = fmt.Sprintf("Error deleting: %v", err)
          } else {
            m.message = fmt.Sprintf("File deleted: %s", m.selectedSudoFile)
          }
          m.state = stateConfirmation
        } else {
          m.backToMain()
        }
      case stateConfirmation:
        m.backToMain()
      }
    }
  }
  return m, nil
}

func (m *model) backToMain() {
  m.options = []string{"Allow sudo without password", "Disable sudo without password", "Exit"}
  m.state = stateMainMenu
  m.cursor = 0
  m.message = ""
  m.action = actionNone
}

func (m model) View() string {
  var s string
  s += styleHeader.Render(fmt.Sprintf("%s %s (c) 2025-present", app, version)) + "\n"
  s += styleSubtleText.Render(githubURL) + "\n"
  if !m.isRoot {
    s += styleSubtleText.Render("\n⚠ Running without root — access to /etc is limited.\n")
  }
  s += "\n"
  switch m.state {
  case stateMainMenu:
    s += "Choose an action:\n\n"
  case stateSelectUser:
    s += "Select a user:\n\n"
  case stateSelectSudoFile:
    s += "Select a sudoers file to remove:\n\n"
  case stateConfirmDelete:
    s += "Confirm deletion:\n\n"
  case stateConfirmation:
    s += m.message + "\n\n" + styleSubtleText.Render("Press Enter to return to menu.")
    return s
  }
  for i, option := range m.options {
    cursor := "  "
    if m.cursor == i {
      cursor = "● "
      s += styleSelected.Render(cursor + option)
    } else {
      s += styleDefault.Render(cursor + option)
    }
    s += "\n"
  }
  s += "\n" + styleSubtleText.Render("↑/↓/k/j - move, Enter - select, q - quit")
  return s
}

func getUsers() []string {
  data, err := os.ReadFile("/etc/passwd")
  if err != nil {
    return nil
  }
  var users []string
  for _, line := range strings.Split(string(data), "\n") {
    if strings.TrimSpace(line) == "" {
      continue
    }
    parts := strings.Split(line, ":")
    if len(parts) >= 6 && strings.HasPrefix(parts[5], "/home/") {
      users = append(users, parts[0])
    }
  }
  return users
}

func getSudoFiles() []string {
  files := []string{}
  filepath.WalkDir("/etc/sudoers.d", func(path string, d fs.DirEntry, err error) error {
    if err != nil {
      return nil
    }
    if !d.IsDir() && strings.HasPrefix(filepath.Base(path), "nopasswd_") {
      files = append(files, path)
    }
    return nil
  })
  return files
}

func addSudoNoPass(user string) error {
  filePath := "/etc/sudoers.d/nopasswd_" + user
  if err := os.WriteFile(filePath, []byte(fmt.Sprintf("%s ALL=(ALL) NOPASSWD: ALL\n", user)), 0440); err != nil {
    return err
  }
  cmd := exec.Command("visudo", "-cf", filePath)
  if err := cmd.Run(); err != nil {
    _ = os.Remove(filePath)
    return fmt.Errorf("syntax error in sudoers file, file removed")
  }
  return nil
}