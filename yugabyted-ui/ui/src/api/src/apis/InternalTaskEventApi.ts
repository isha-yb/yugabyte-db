// tslint:disable
/**
 * Yugabyte Cloud
 * YugabyteDB as a Service
 *
 * The version of the OpenAPI document: v1
 * Contact: support@yugabyte.com
 *
 * NOTE: This class is auto generated by OpenAPI Generator (https://openapi-generator.tech).
 * https://openapi-generator.tech
 * Do not edit the class manually.
 */

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { useQuery, useInfiniteQuery, useMutation, UseQueryOptions, UseInfiniteQueryOptions, UseMutationOptions } from 'react-query';
import Axios from '../runtime';
import type { AxiosInstance } from 'axios';
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import type {
  ApiError,
} from '../models';

export interface EventCallbackForQuery {
  eventId: string;
}

/**
 * Post a task-related event callback
 * Post a task-related event callback
 */


export const eventCallbackMutate = (
  body: EventCallbackForQuery,
  customAxiosInstance?: AxiosInstance
) => {
  const url = '/private/taskEvents/{eventId}'.replace(`{${'eventId'}}`, encodeURIComponent(String(body.eventId)));
  // eslint-disable-next-line
  // @ts-ignore
  delete body.eventId;
  return Axios<unknown>(
    {
      url,
      method: 'POST',
    },
    customAxiosInstance
  );
};

export const useEventCallbackMutation = <Error = ApiError>(
  options?: {
    mutation?:UseMutationOptions<unknown, Error>,
    customAxiosInstance?: AxiosInstance;
  }
) => {
  const {mutation: mutationOptions, customAxiosInstance} = options ?? {};
  // eslint-disable-next-line
  // @ts-ignore
  return useMutation<unknown, Error, EventCallbackForQuery, unknown>((props) => {
    return  eventCallbackMutate(props, customAxiosInstance);
  }, mutationOptions);
};





