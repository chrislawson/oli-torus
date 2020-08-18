defmodule Oli.LtiTest do
  use Oli.DataCase

  alias Oli.Lti

  describe "key generator" do
    test "passphrase/0 generates a random passphrase of size 256" do
      assert String.length(Lti.passphrase) == 256
    end

    test "generate_key_pair/0 generates a public and private key pair" do
      keypair = Lti.generate_key_pair
      assert Map.has_key?(keypair, :public_key)
      assert Map.has_key?(keypair, :private_key)
    end

  end
end
