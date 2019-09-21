# SSH public keys, stored in an attribute set hierarchy of <host>.<user>.<description>.
#
# Suggestion on where to store the keys on the client side.
# Default key: ~/.ssh/id_<algo>
# Other keys:  ~/.ssh/id_<algo>_<description>

{
  media.root.backup = ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJsLLEZxPtdFQJVqG8zOuBZTUYHhhh026F2BDsHXJXPW root@media (for backup automation)'';
  media.root.nix_remote_build = ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILoDrnvYjSPBWVLgwmuVaOUTnNF1ASaO7Y+oej+6WRBm root@media (nix remote build)'';

  mini.root.backup = ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPCwtdqwE2WLolrNQmf5M/DmzaKjG29yq0lr4WgUa2z7 root@mini (for backup automation)'';
  mini.root.nix_remote_build = ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE62OwZK96RYNiHbVWpQR+aD98wJn9TFmjKTnCV9pv5k root@mini (nix remote build)'';

  mini.bf.default = ''ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDTl8tsKUmHqO5eJoPvAVSu5vm7Ibml9rYxAblTUU/dl+zip7RNfl178qaX4nwUHkI3qsITJ8yQr42iIanvIPpCvM5V4rYjDmD7R4R8wSvzsrxegipG+kXfItlgsmCIuNsYZNCPtxESsLMW6tuJBfFy8L0IGmwYXLNNj7NIsrI4ElOhmWHz+VppZU1R74IghC+ZWJkkqoc9Ayt17ezLfBPYYuoan60H2/KOBtJX5qjfdxGXF5H7Oa7SBE/0zZ5Eaq8MudM/7CClc2nA787xadp8O6aQoF/ZB27dwr3mK2IugYc7w2rDlT67iQHLT27LKMU74CY//xSqkGUZOyGDAN7B bf@mini'';

  whitetip.bf.default = ''ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCfy7XFi35G277tbjGzFeFdbtz8c3b9dQcBpE9KlcVVKMG9mMzVQeLJkehqi/NGyzV7DcJgvFW0vFJaRbQbOVuIlnC3rCwO+NUJW+48aarnna1Izv6ihHp5vprYhZT9AANfUUsaCy5ZBVljlJ34S8gJNvmq7oogh9ioi9hE3LvdZMC0M6k2WZG5+lPlDWbNjuWlYF9e9XVJlopU+xfNy98u0djyBo2urkqtNT8vXu49JarKpxgi3tMDv2pZFNNICukWsg8EEH6YIhJjsiO0RdnanzO/yQK2/SQtq0GjnzEaRilAgiUnGHC7f7iOBeNhc+hUcKltBlWmPsF9ZV5txZDT bf@whitetip'';
  whitetip.root.nix_remote_build = ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBOgHOn3+Sr8WUZQiEVN3NZ6nXOL1NPUSo2Sen+63G6j root@whitetip (nix remote build)'';
  whitetip.root.backup = ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAMnppoIYKUmeW09hw2nEofL3aDL12T/P8P81HMnwPpE root@whitetip (for backup automation)'';

  my_phone.user.default = ''ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDZ63+kGCJbSI8P8LThqXJHZdiGWHpR7K/NUkimWn+3r4y22JhuRLpUHnHRfvPm16HIbrVwrHbZ6vxqvxx7hP9UGRTdRT9HjOvVoOQGIYjRtjrRiMHE/DmrBxdQ5FtQVeARKcNCWYIlubtuxg1c6ZD0fScs5yWrlumblsQxJgqS5K6csyh9yZL8rtBC0VqkroynMoYONqTTAAnx6lg9X6t2FZ3SFqCZ5VYk9DkwLZNIrwwEF87tQSuCSTX8pKw9THP0H07pafR0hWwKHuhPqbK7qlE1ZXzVtbujg/GndLbjFFV7Lpkc5h5B+fC4VBAiaKG9DQSV5LNRjrolprQkijNiFNqojnsCSJVDHSercDSTLNsN2wNPKXUlzkNyWEnefvPFrW1vPBoTF8YrPICNOi8mGLkX+ygP0ROycuKupSqkfAjXqdabAnuHNZHI1gY9j4/qlK5YhgbOu1pWVe9xVKCEfR0MG/iTi83ExiDlkzGgOcFkiDoUaKF6HMM2w6u+pgwDSsP8jmHrUuGqib3mMm3M7VMoGvxQE+T8bQ53G1/z/FI3xITpnNUs61DtUxf6uSCYJFDE5vRYSAnPW9L7/dLo5klJbDbyGyHgneFeGb5gdQEqhUZHXHXwCPyH5fn2XLA6DErMGWAvEqNVs6p2XO54UY/HuKnjr1W8eMqLVMpvVw== My phone'';
}
