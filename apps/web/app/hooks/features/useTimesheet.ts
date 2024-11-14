import { useAuthenticateUser } from './useAuthenticateUser';
import { useAtom } from 'jotai';
import { timesheetRapportState } from '@/app/stores/time-logs';
import { useQuery } from '../useQuery';
import { useCallback, useEffect } from 'react';
import { deleteTaskTimesheetLogsApi, getTaskTimesheetLogsApi } from '@/app/services/client/api/timer/timer-log';
import moment from 'moment';
import { ITimeSheet } from '@/app/interfaces';

interface TimesheetParams {
    startDate: Date | string;
    endDate: Date | string;
}

export interface GroupedTimesheet {
    date: string;
    tasks: ITimeSheet[];
}


const groupByDate = (items: ITimeSheet[]): GroupedTimesheet[] => {
    if (!items?.length) return [];
    type GroupedMap = Record<string, ITimeSheet[]>;
    const groupedByDate = items.reduce<GroupedMap>((acc, item) => {
        if (!item?.createdAt) return acc;
        try {
            const date = new Date(item.createdAt).toISOString().split('T')[0];
            if (!acc[date]) acc[date] = [];
            acc[date].push(item);
        } catch (error) {
            console.error('Invalid date format:', item.createdAt);
        }
        return acc;
    }, {});

    return Object.entries(groupedByDate)
        .map(([date, tasks]) => ({ date, tasks }))
        .sort((a, b) => b.date.localeCompare(a.date));
}


export function useTimesheet({
    startDate,
    endDate,
}: TimesheetParams) {
    const { user } = useAuthenticateUser();
    const [timesheet, setTimesheet] = useAtom(timesheetRapportState);

    const { loading: loadingTimesheet, queryCall: queryTimesheet } = useQuery(getTaskTimesheetLogsApi);
    const { loading: loadingDeleteTimesheet, queryCall: queryDeleteTimesheet } = useQuery(deleteTaskTimesheetLogsApi)

    const getTaskTimesheet = useCallback(
        ({ startDate, endDate }: TimesheetParams) => {
            if (!user) return;
            const from = moment(startDate).format('YYYY-MM-DD');
            const to = moment(endDate).format('YYYY-MM-DD')
            queryTimesheet({
                startDate: from,
                endDate: to,
                organizationId: user.employee?.organizationId,
                tenantId: user.tenantId ?? '',
                timeZone: user.timeZone?.split('(')[0].trim(),
            }).then((response) => {
                setTimesheet(response.data);
            }).catch((error) => {
                console.error('Error fetching timesheet:', error);
            });
        },
        [user, queryTimesheet, setTimesheet]
    );


    const deleteTaskTimesheet = useCallback(() => {
        if (!user) return;
        queryDeleteTimesheet({
            organizationId: user.employee.organizationId,
            tenantId: user.tenantId ?? "",
            logIds: []
        })
    }, [])


    useEffect(() => {
        getTaskTimesheet({ startDate, endDate });
    }, [getTaskTimesheet, startDate, endDate]);



    return {
        loadingTimesheet,
        timesheet: groupByDate(timesheet),
        getTaskTimesheet,
        loadingDeleteTimesheet,
        deleteTaskTimesheet
    };
}
