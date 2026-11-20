# Backup pi entry point: identical agent, backup provider. Used when the
# QwenCloud token plan is down (outage, quota, endpoint retired). The
# openrouter credential comes from ~/.pi/agent/auth.json like normal pi.
exec pi --provider openrouter --model deepseek/deepseek-v4.1-flash "$@"
