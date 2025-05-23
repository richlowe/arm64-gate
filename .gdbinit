define load-kernel-modules
  # Skip 'unix', we loaded that ourselves to find 'modules'
  set $_module = modules->mod_next
  while $_module != &modules
    set $_file = $_module->mod_filename
    if $_module->mod_loaded
      set $_filename = (*(struct module *)$_module->mod_mp)->filename
      set $_text = (uintptr_t)((*(struct module *)$_module->mod_mp)->text)
      set $_data = (uintptr_t)((*(struct module *)$_module->mod_mp)->data)
      eval "add-symbol-file ./illumos-gate/proto/root_aarch64/%s -s .text %p -s .data %p", $_filename, $_text, $_data
    end
    set $_module = $_module->mod_next
  end
end

define devinfo
  printf "name: %s\n", ((struct dev_info *)$arg0)->devi_node_name
  printf "binding: %s\n", ((struct dev_info *)$arg0)->devi_binding_name
end

file illumos-gate/proto/root_aarch64/platform/armv8/kernel/aarch64/unix
