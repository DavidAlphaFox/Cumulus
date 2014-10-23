echo "yes" | sudo add-apt-repository ppa:avsm/ocaml41+opam11
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam
sudo apt-get install libpcre3-dev libssl-dev
export OPAMYES=1
opam init
eval `opam config env`
case $OCSIGENSERVER3 in
    true)
        opam repository add cumulus https://github.com/Cumulus/opam-cumulus.git;;
    false)
        opam repository add cumulus https://github.com/Cumulus/opam-cumulus.git#ocsigenserver-3.0.0;;
    *)
        echo Unknown variable '$OCSIGENSERVER3': $OCSIGENSERVER3
esac
opam install cumulus-deps
make
