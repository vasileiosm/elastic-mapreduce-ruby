#
# Copyright 2011-2013 Amazon.com, Inc. or its affiliates.  All Rights Reserved.

class SimpleExecutor
  def exec(cmd)
    puts(cmd)
    if ! system(cmd) then
      raise RuntimeError, "Command failed."
    end
  end
end
