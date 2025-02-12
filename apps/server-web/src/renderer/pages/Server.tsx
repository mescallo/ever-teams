import { useState, useEffect } from 'react';
import { ServerPageTypeMessage } from '../../main/helpers/constant';
import { IPC_TYPES, LOG_TYPES } from '../../main/helpers/constant';
import { EverTeamsLogo } from '../components/svgs';
import { useTranslation } from 'react-i18next';

export function ServerPage() {
  const [isRun, setIsRun] = useState<boolean>(false);
  const [logs, setLogs] = useState<string[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const { t } = useTranslation();

  useEffect(() => {
    window.electron.ipcRenderer.removeEventListener(IPC_TYPES.SERVER_PAGE);
    window.electron.ipcRenderer.on(IPC_TYPES.SERVER_PAGE, (arg: any) => {
      switch (arg.type) {
        case LOG_TYPES.SERVER_LOG:
          setLogs((prev) => [...prev, arg.msg]);
          break;
        case ServerPageTypeMessage.SERVER_STATUS:
          if (arg.data.isRun) {
            setIsRun(true);
          } else {
            setIsRun(false);
          }
          setLoading(false);
          break;
        default:
          break;
      }
    });
  }, []);

  const runServer = () => {
    setLoading(true);
    window.electron.ipcRenderer.sendMessage(IPC_TYPES.SERVER_PAGE, {
      type: ServerPageTypeMessage.SERVER_EXEC,
      data: {
        isRun: !isRun,
      },
    });
  };

  return (
    <div className="min-h-screen flex flex-col flex-auto flex-shrink-0 antialiased text-gray-800">
      <div className="rounded-lg px-16 py-10">
        <div className="flex justify-center">
          <EverTeamsLogo />
        </div>
      </div>
      <button
        className="flex block rounded-lg border-4 border-transparent items-center bg-violet-800 px-6 py-2 text-center text-base font-medium text-100 w-fit mx-auto my-5 text-gray-200"
        onClick={runServer}
        disabled={loading}
      >
        {loading && (
          <div className="w-4 h-4 border-4 border-blue-500 border-dotted rounded-full animate-spin m-auto"></div>
        )}
        <span>{isRun ? t('FORM.BUTTON.STOP') : t('FORM.BUTTON.START')}</span>
      </button>
      <div className="grid divide-y divide-neutral-200 dark:bg-[#25272D] dark:text-white mx-auto w-10/12 rounded-lg border-2 border-gray-200 dark:border-gray-600">
        <div className="py-5 px-5">
          <details className="group">
            <summary className="flex justify-between items-center font-medium cursor-pointer list-none">
              <span className="p-2"> Server Logs</span>
              <span className="transition group-open:rotate-180">
                <svg
                  fill="none"
                  height="24"
                  shapeRendering="geometricPrecision"
                  stroke="currentColor"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="1.5"
                  viewBox="0 0 24 24"
                  width="24"
                >
                  <path d="M6 9l6 6 6-6"></path>
                </svg>
              </span>
            </summary>
            <div
              className="inline-block w-full bg-black dark:bg-black text-white text-xs leading-3 rounded-lg"
              style={{
                minHeight: '350px',
                maxHeight: '350px',
                overflowY: 'auto',
              }}
            >
              <div className="ml-1 mt-1 p-2">
                {logs.length > 0 &&
                  logs.map((log, i) => (
                    <div className="py-1" key={i}>
                      <span>{log}</span>
                    </div>
                  ))}
              </div>
            </div>
          </details>
        </div>
      </div>
    </div>
  );
}
