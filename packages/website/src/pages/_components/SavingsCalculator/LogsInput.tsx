import type { Component } from "solid-js";

import { IntegerInput } from "@/components/inputs/IntegerInput.tsx";
import {
  calculatorStore,
  setCalculatorStore,
} from "@/pages/_components/calculatorStore.tsx";

const LogsInput: Component = () => {
  return (
    <IntegerInput
      id={"logs"}
      label={"GB Logs / Month"}
      value={calculatorStore.logs}
      max={100000}
      onChange={(newVal) => {
        setCalculatorStore("logs", newVal);
      }}
    />
  );
};

export default LogsInput;
