import { CloudTasksClient } from "@google-cloud/tasks";

const PROJECT_ID = "min-rescue";
const LOCATION = "asia-south1";
const QUEUE_NAME = "timeout-queue";
const FUNCTIONS_BASE_URL = `https://${LOCATION}-${PROJECT_ID}.cloudfunctions.net`;

const tasksClient = new CloudTasksClient();

export async function enqueueDriverTimeout(
  requestId: string,
  currentRadius: number
): Promise<void> {
  const parent = tasksClient.queuePath(PROJECT_ID, LOCATION, QUEUE_NAME);
  const url = `${FUNCTIONS_BASE_URL}/onDriverTimeout`;

  await tasksClient.createTask({
    parent,
    task: {
      httpRequest: {
        httpMethod: "POST",
        url,
        headers: { "Content-Type": "application/json" },
        body: Buffer.from(
          JSON.stringify({ requestId, currentRadius })
        ).toString("base64"),
        oidcToken: {
          serviceAccountEmail: `${PROJECT_ID}@appspot.gserviceaccount.com`,
        },
      },
      scheduleTime: {
        seconds: Math.floor(Date.now() / 1000) + 30,
      },
    },
  });
}

export async function enqueueHospitalTimeout(
  requestId: string,
  currentRadius: number
): Promise<void> {
  const parent = tasksClient.queuePath(PROJECT_ID, LOCATION, QUEUE_NAME);
  const url = `${FUNCTIONS_BASE_URL}/onHospitalTimeout`;

  await tasksClient.createTask({
    parent,
    task: {
      httpRequest: {
        httpMethod: "POST",
        url,
        headers: { "Content-Type": "application/json" },
        body: Buffer.from(
          JSON.stringify({ requestId, currentRadius })
        ).toString("base64"),
        oidcToken: {
          serviceAccountEmail: `${PROJECT_ID}@appspot.gserviceaccount.com`,
        },
      },
      scheduleTime: {
        seconds: Math.floor(Date.now() / 1000) + 30,
      },
    },
  });
}
