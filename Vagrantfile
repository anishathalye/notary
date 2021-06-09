Vagrant.configure(2) do |config|

  config.vm.box = 'ubuntu/bionic64'

  # synced folder
  config.vm.synced_folder '.', '/notary'

  # disable default synced folder
  config.vm.synced_folder '.', '/vagrant', disabled: true

  # install dependencies
  config.vm.provision 'shell', inline: <<-EOS
    apt-get remove -y --purge man-db
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      build-essential clang bison flex libreadline-dev \
      gawk tcl-dev libffi-dev git graphviz xdot pkg-config python3 \
      libboost-system-dev libboost-python-dev libboost-filesystem-dev \
      zlib1g-dev python3-pip gcc-riscv64-linux-gnu
  EOS

  config.vm.provision 'shell', privileged: false, inline: <<-EOS
    /notary/.ci/install-yosys.sh

    /notary/.ci/install-racket.sh

    pip3 install bin2coe

    echo > ~/.bashrc 'PATH="${HOME}/yosys:${HOME}/racket/bin:${HOME}/.local/bin:${PATH}"'

    ~/racket/bin/raco pkg install --no-docs --batch --auto https://github.com/anishathalye/rtlv.git
  EOS

end
