import * as React from "react";

import { useClientAlert } from "$app/components/ClientAlertProvider";
import { DateRangePicker } from "$app/components/DateRangePicker";

const MAX_DAYS = 31;

export const ChurnDateRangePicker = ({
  from,
  to,
  setFrom,
  setTo,
}: {
  from: Date;
  to: Date;
  setFrom: (from: Date) => void;
  setTo: (to: Date) => void;
}) => {
  const { showAlert } = useClientAlert();

  const validateAndSet = (newFrom: Date, newTo: Date) => {
    const days = Math.ceil((newTo.getTime() - newFrom.getTime()) / (1000 * 60 * 60 * 24)) + 1;
    if (days <= MAX_DAYS) {
      setFrom(newFrom);
      setTo(newTo);
    } else {
      showAlert(`Date range cannot exceed ${MAX_DAYS} days. Selected: ${days} days.`, "error");
    }
  };

  const handleSetFrom = (date: Date) => {
    validateAndSet(date, to);
  };

  const handleSetTo = (date: Date) => {
    validateAndSet(from, date);
  };

  return (
    <DateRangePicker
      from={from}
      to={to}
      setFrom={handleSetFrom}
      setTo={handleSetTo}
    />
  );
};
