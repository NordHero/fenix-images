#!/usr/bin/env bash

export TOOL_NAME="aws"
export TOOL_LAYER="cloud-ops"
export TOOL_ANCHOR="pgp(FB5D..475C)"
export TOOL_ANCHOR_STRENGTH="vendor-pgp"
export TOOL_SIZE="~160MB"
export TOOL_UPDATE="bump-pr+rebuild"

AWS_PGP_FINGERPRINT="FB5DB77FD5C118B80511ADA8A6310ACC4672475C"
AWS_SOURCE_URL="https://awscli.amazonaws.com/awscli.tar.gz"

AWS_PGP_KEY='-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBF2Cr7UBEADJZHcgusOJl7ENSyumXh85z0TRV0xJorM2B/JL0kHOyigQluUG
ZMLhENaG0bYatdrKP+3H91lvK050pXwnO/R7fB/FSTouki4ciIx5OuLlnJZIxSzx
PqGl0mkxImLNbGWoi6Lto0LYxqHN2iQtzlwTVmq9733zd3XfcXrZ3+LblHAgEt5G
TfNxEKJ8soPLyWmwDH6HWCnjZ/aIQRBTIQ05uVeEoYxSh6wOai7ss/KveoSNBbYz
gbdzoqI2Y8cgH2nbfgp3DSasaLZEdCSsIsK1u05CinE7k2qZ7KgKAUIcT/cR/grk
C6VwsnDU0OUCideXcQ8WeHutqvgZH1JgKDbznoIzeQHJD238GEu+eKhRHcz8/jeG
94zkcgJOz3KbZGYMiTh277Fvj9zzvZsbMBCedV1BTg3TqgvdX4bdkhf5cH+7NtWO
lrFj6UwAsGukBTAOxC0l/dnSmZhJ7Z1KmEWilro/gOrjtOxqRQutlIqG22TaqoPG
fYVN+en3Zwbt97kcgZDwqbuykNt64oZWc4XKCa3mprEGC3IbJTBFqglXmZ7l9ywG
EEUJYOlb2XrSuPWml39beWdKM8kzr1OjnlOm6+lpTRCBfo0wa9F8YZRhHPAkwKkX
XDeOGpWRj4ohOx0d2GWkyV5xyN14p2tQOCdOODmz80yUTgRpPVQUtOEhXQARAQAB
tCFBV1MgQ0xJIFRlYW0gPGF3cy1jbGlAYW1hem9uLmNvbT6JAlQEEwEIAD4CGwMF
CwkIBwIGFQoJCAsCBBYCAwECHgECF4AWIQT7Xbd/1cEYuAURraimMQrMRnJHXAUC
akV0ygUJDqP4lQAKCRCmMQrMRnJHXFHjD/9eyZLYcKuQOlLvtqSDtUBiEZf6ZZjM
i3ygYH8rJNtuToUH+HvSpe819urJCquXhDrlK6N+aqW0hCLtNABJG/vsafIgvIYJ
hSGgpgtNnQyMV1jViRWqPjbouw8OkYKBThUfT1i2Y+wn58ifs6ODBCmTexWtXspA
Si+Gt49xDOW0APmbOPnI+a4HJW6tVEo6MWS0WjzpiBayR3d1A4pt4YrPfSdDgpLo
h2SLQqlRqvvVZJaWBjhkErNFpfsBA06sDcPEOb0G8LBUbR4WOcdvhe5LubJbZuxC
AG9kNPCVeQP1ixwjgjXKysaxeQ6rv0VzIQgRp6tLVLWhy6AKDNvLjFSsmXZ1Wl08
Y/RlOHXlzLuQMRE6sR1wOdRxc9TsrNWTGiBK65cvSWOy03JeBkQQ8pesqltiyxI9
U21kkgiXtTSKNGfKK8pO27D81YANhRqPK7iTp6kuFiY2WtOg90KTMNlIT+Ff85Y2
b1rHj6Z0SrCkJujhWk3IBPic/wJgz01LEc/OAdUPlby90RJZcIBhSlWhT7mXnXIO
c0HWlNQrns2s3CTyYwZSiSlYe9ApeLwhjDo8NhbFuCAy61l6O5UsR4AfZxx/rGKv
2wFb1/RN/P4gNe6vmxZAPjR0AQcwD3tc2McimOLr/22kmPz8IH3I0X7WoSFr0Biz
E91G7bb0hOb/cA==
=knv7
-----END PGP PUBLIC KEY BLOCK-----'

tool_install() {
  set -euo pipefail

  apt-get update
  apt-get install -y --no-install-recommends \
    gcc make libffi-dev libssl-dev zlib1g-dev \
    python3-dev python3-venv groff
  rm -rf /var/lib/apt/lists/*

  work="$(mktemp -d)"
  export GNUPGHOME="$work/gnupg"
  mkdir -p "$GNUPGHOME"
  chmod 700 "$GNUPGHOME"

  printf '%s\n' "$AWS_PGP_KEY" >"$work/aws.asc"
  got="$(gpg --show-keys --with-colons --with-fingerprint "$work/aws.asc" | awk -F: '/^fpr:/{print $10; exit}')"
  test "$got" = "$AWS_PGP_FINGERPRINT"
  gpg --batch --import "$work/aws.asc"

  curl -fsSL "$AWS_SOURCE_URL" -o "$work/awscli.tar.gz"
  curl -fsSL "${AWS_SOURCE_URL}.sig" -o "$work/awscli.tar.gz.sig"
  gpg --batch --verify "$work/awscli.tar.gz.sig" "$work/awscli.tar.gz"

  mkdir -p "$work/src"
  tar -xzf "$work/awscli.tar.gz" -C "$work/src" --strip-components=1

  (
    cd "$work/src"
    PYTHON=/usr/bin/python3 ./configure \
      --with-install-type=system-sandbox \
      --with-download-deps
    make
    make install
  )

  rm -rf "$work"
  ln -sf /usr/local/bin/aws /usr/bin/aws

  aws --version
}
