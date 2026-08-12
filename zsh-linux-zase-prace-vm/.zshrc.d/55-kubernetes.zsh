# Kubernetes.
#
# Cluster configs live one-file-per-cluster in ~/.kube/configs/ and are never
# merged onto disk. kubie is the primary interface: `kubie ctx` spawns a
# subshell holding its own isolated KUBECONFIG, so two terminals can sit on
# two different clusters at the same time without interfering. Plain
# `kubectl config use-context` cannot do that — it mutates shared state.
#
# The merged KUBECONFIG below is only a fallback, so a bare kubectl run
# outside a kubie shell can still see every cluster.

KUBE_CONFIG_DIR="$HOME/.kube/configs"

_kubeconfigs=()

# ~/.kube/config is deliberately FIRST. kubectl writes context changes to the
# first entry of KUBECONFIG, so stray writes land in that scratch file instead
# of quietly rewriting a pristine per-cluster file.
[[ -f $HOME/.kube/config ]] && _kubeconfigs+=("$HOME/.kube/config")

# (N) is the null_glob qualifier: a pattern matching nothing expands to
# nothing, instead of being passed through to kubectl as a bogus path.
_kubeconfigs+=(${KUBE_CONFIG_DIR}/*.yaml(N) ${KUBE_CONFIG_DIR}/*.yml(N))

if (( ${#_kubeconfigs} )); then
    export KUBECONFIG="${(j.:.)_kubeconfigs}"
fi
unset _kubeconfigs

if (( $+commands[kubie] )); then
    alias kctx='kubie ctx'
    alias kns='kubie ns'
fi
