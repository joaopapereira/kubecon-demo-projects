load("@ytt:data", "data")

def crdAPIVersion(): return data.values.crd.group+"/"+data.values.crd.version

def projectsCRD(): return "projects."+data.values.crd.group
