{
  flake.templates = {
    ml = {
      path = ../templates/ml;
      description = "ML dev environment — Python, MLflow, DVC, Jupyter";
    };

    python = {
      path = ../templates/python;
      description = "Python project — uv deps, ruff + ty (helix-default LSPs), pytest/hypothesis/IPython dev group";
    };

    rust = {
      path = ../templates/rust;
      description = "Rust project — cargo + clippy + rustfmt + rust-analyzer + bacon from a nix dev shell";
    };
  };
}
