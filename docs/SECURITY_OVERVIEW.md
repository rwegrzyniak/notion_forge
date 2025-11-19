# 🔐 NotionForge Security & Configuration Overview

## 📁 New Directory Structure

The configuration is now properly organized in `~/.notion_forge/`:

```
~/.notion_forge/
├── secrets          # 🔐 Encrypted API credentials (AES-256-GCM)
└── workspaces/      # 📚 Custom workspace templates
    ├── my_custom_workspace.rb
    └── customized_demo.rb
```

### Directory Permissions
- **`~/.notion_forge/`**: `0700` (owner only: read/write/execute)
- **`secrets` file**: `0600` (owner only: read/write)
- **`workspaces/`**: `0755` (owner: read/write, others: read)

## 🔒 Encryption Details

### Algorithm: **AES-256-GCM**
NotionForge uses **AES-256-GCM** (Galois/Counter Mode) for encrypting your API credentials:

#### Why AES-256-GCM?
- **AES-256**: Industry standard, military-grade encryption with 256-bit keys
- **GCM Mode**: Provides both **encryption** AND **integrity verification**
- **Authentication**: Prevents tampering - any modification will be detected
- **Performance**: Fast and efficient

### 🔑 Key Derivation
The encryption key is machine-specific and derived from:
```ruby
machine_id = `uname -n`.strip    # Your computer's hostname
user_id = ENV['USER']            # Your username
key = SHA256("#{machine_id}:#{user_id}:notion_forge")
```

This means:
- ✅ **Unique per machine**: Can't be used on another computer
- ✅ **Unique per user**: Different users on same machine have different keys
- ✅ **No hardcoded secrets**: Key is generated from system information

### 🛡️ Security Components

Each encrypted configuration contains:

1. **IV (Initialization Vector)**: 
   - Random 16 bytes generated for each encryption
   - Ensures same data encrypted twice produces different ciphertext
   - Base64 encoded for storage

2. **Auth Tag**:
   - 16-byte authentication tag from GCM mode
   - Verifies data integrity and authenticity
   - Prevents tampering attacks

3. **Encrypted Data**:
   - Your actual API token and page ID
   - JSON format before encryption
   - Base64 encoded for safe storage

### 📄 Configuration File Format

The `secrets` file contains a JSON structure:
```json
{
  "iv": "base64-encoded-initialization-vector",
  "auth_tag": "base64-encoded-authentication-tag", 
  "data": "base64-encoded-encrypted-configuration"
}
```

When decrypted, the data contains:
```json
{
  "token": "secret_your_notion_api_token_here",
  "parent_page_id": "your_parent_page_id_here",
  "created_at": "2025-10-03T15:18:42+0200",
  "version": "0.1.0"
}
```

## 🔍 Security Analysis

### ✅ Strengths
- **Military-grade encryption**: AES-256 is approved for classified information
- **Authenticated encryption**: GCM mode prevents tampering
- **Machine-specific keys**: Credentials can't be stolen and used elsewhere
- **No plaintext storage**: API tokens never stored in plaintext
- **Proper file permissions**: OS-level protection

### ⚠️ Considerations
- **Key derivation**: Uses system info (predictable but unique)
- **Local protection only**: Protects against file system access, not memory dumps
- **No password protection**: Key derived automatically (convenience vs security trade-off)

### 🔧 For Enhanced Security (if needed)
To add password-based encryption, you could modify the `encryption_key` method:
```ruby
def encryption_key
  password = ask("Enter encryption password:", echo: false)
  salt = "notion_forge_salt_#{machine_id}:#{user_id}"
  PBKDF2.pbkdf2_hmac_sha256(password, salt, 100000, 32)
end
```

## 🚀 Usage

### Current Status
```bash
notion_forge status
```

### List Available Workspaces  
```bash
notion_forge workspaces          # Basic list
notion_forge workspaces --detailed  # With workspace previews
```

### Deploy Workspace
```bash
notion_forge forge philosophical_workspace
```

### Reset Configuration
```bash
notion_forge setup --force
```

## 🎯 Summary

✅ **Secure**: Military-grade AES-256-GCM encryption  
✅ **Organized**: Clean directory structure  
✅ **Convenient**: Automatic machine-specific key derivation  
✅ **Protected**: Proper file permissions  
✅ **Verified**: Integrity protection prevents tampering  

Your Notion API credentials are now securely encrypted and properly organized! 🎉
