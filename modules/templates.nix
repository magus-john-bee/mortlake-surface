{
  flake.templates.ml = {
    path = ../templates/ml;
    description = "ML dev environment — Python, MLflow, DVC, Jupyter";
  };

  flake.templates.python = {
    path = ../templates/python;
    description = "Python project — uv deps, ruff + ty (helix-default LSPs), pytest/hypothesis/IPython dev group";
  };
}
